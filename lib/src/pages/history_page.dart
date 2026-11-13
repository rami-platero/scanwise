import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../utils/format_util.dart';
import '../utils/icon_string_util.dart';

/// List of every product scanned so far (READ), with swipe-to-delete
/// (DELETE) and pull-to-refresh. Data comes straight from Supabase.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Product>? _products;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _products = null;
    });

    try {
      final List<Product> products = await productService.fetchHistory();
      if (!mounted) return;
      setState(() => _products = products);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not load the history: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _load,
          ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) return _errorState(_error!);
    if (_products == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // RefreshIndicator needs a scrollable child even for the empty state,
    // otherwise the pull-down gesture has nothing to grab.
    if (_products!.isEmpty) {
      return RefreshIndicator(onRefresh: _load, child: _emptyState(context));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: _list(context, _products!),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return ListView(
      // So the gesture works, but still reads as a centered empty state.
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox_outlined, size: 56, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Todavia no escaneaste ningun producto'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pushNamed(context, 'camera'),
                  child: const Text('Escanear uno'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _list(BuildContext context, List<Product> products) {
    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (BuildContext context, int i) =>
          const Divider(height: 1),
      itemBuilder: (BuildContext context, int i) {
        final Product product = products[i];

        return Dismissible(
          key: Key(product.id ?? '$i-${product.name}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (DismissDirection direction) =>
              _deleteProduct(product, i),
          child: _productTile(context, product),
        );
      },
    );
  }

  Future<void> _deleteProduct(Product product, int index) async {
    // Remove it from the list right away so the UI feels instant...
    setState(() => _products!.removeAt(index));

    try {
      await productService.delete(product);
    } catch (error) {
      // ...and put it back if the delete actually failed on the server.
      if (!mounted) return;
      setState(() => _products!.insert(index, product));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $error')),
      );
    }
  }

  Widget _productTile(BuildContext context, Product product) {
    final bool pending = !product.isExactModel;

    return ListTile(
      leading: _thumbnail(product),
      title: Text(product.name),
      subtitle: Text('${product.category} - ${product.scannedAt}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${money(product.priceMin)} - ${money(product.priceMax)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (pending)
            const Text(
              'Sin confirmar',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
        ],
      ),
      // If it was left unconfirmed, tapping it resumes the photo guidance.
      onTap: () => Navigator.pushNamed(
        context,
        pending ? 'guidance' : 'result',
        arguments: product,
      ),
    );
  }

  /// Same priority as result_page: curated cover, then the real photo
  /// (now persisted - see ProductService._persistPhoto), then the icon.
  Widget _thumbnail(Product product) {
    final BorderRadius radius = BorderRadius.circular(8);

    if (product.catalogImageAsset != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          product.catalogImageAsset!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }

    if (product.photoPath != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(product.photoPath!),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }

    return getIcon(product.icon, size: 32);
  }
}
