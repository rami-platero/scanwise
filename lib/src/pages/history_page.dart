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

  final TextEditingController _searchController = TextEditingController();

  /// Free-text search, lowercased once instead of on every comparison.
  String _query = '';

  /// null means "todas"; otherwise one of the categories actually
  /// present in the data, so the app never offers an empty filter.
  String? _category;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Matches against everything the user might remember about an item,
  /// not just its title: platform and brand are often what comes to
  /// mind first ("el de PlayStation 2").
  List<Product> _visible(List<Product> products) {
    return products.where((Product product) {
      if (_category != null && product.category != _category) return false;
      if (_query.isEmpty) return true;

      final String haystack = [
        product.name,
        product.platform,
        product.brand,
        product.model,
      ].join(' ').toLowerCase();

      return haystack.contains(_query);
    }).toList();
  }

  List<String> _categoriesIn(List<Product> products) {
    final Set<String> categories = products
        .map((Product product) => product.category)
        .where((String category) => category.isNotEmpty)
        .toSet();
    final List<String> sorted = categories.toList()..sort();
    return sorted;
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
      setState(() => _error = 'No se pudo cargar el historial: $error');
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

    final List<Product> visible = _visible(_products!);

    return Column(
      children: [
        _filters(context, _products!),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: visible.isEmpty
                ? _noMatchesState(context)
                : _list(context, visible),
          ),
        ),
      ],
    );
  }

  Widget _filters(BuildContext context, List<Product> products) {
    final List<String> categories = _categoriesIn(products);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar por titulo, plataforma o marca',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Limpiar',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
            onChanged: (String value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
          // A single category means the filter row would only ever offer
          // "todas" and that one - no point taking up the space.
          if (categories.length > 1)
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _categoryChip(label: 'Todas', value: null),
                  for (final String category in categories)
                    _categoryChip(label: category, value: category),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryChip({required String label, required String? value}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: FilterChip(
          label: Text(label),
          selected: _category == value,
          onSelected: (bool selected) =>
              setState(() => _category = selected ? value : null),
        ),
      ),
    );
  }

  Widget _noMatchesState(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('Ningun producto coincide con la busqueda'),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                      _category = null;
                    });
                  },
                  child: const Text('Limpiar filtros'),
                ),
              ],
            ),
          ),
        ),
      ],
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
          onDismissed: (DismissDirection direction) => _deleteProduct(product),
          child: _productTile(context, product),
        );
      },
    );
  }

  /// Works off the product itself rather than its row position: the list
  /// on screen can be filtered, so an index into it wouldn't line up
  /// with the full list this removes from.
  Future<void> _deleteProduct(Product product) async {
    final int index = _products!.indexOf(product);
    if (index == -1) return;

    // Remove it from the list right away so the UI feels instant...
    setState(() => _products!.removeAt(index));

    try {
      await productService.delete(product);
    } catch (error) {
      // ...and put it back if the delete actually failed on the server.
      if (!mounted) return;
      setState(() => _products!.insert(index, product));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $error')));
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
      // Always the result screen: the guidance step needs a live
      // identification session, which no longer exists for a saved row.
      // From there the user can rescan if the match looks wrong.
      onTap: () => Navigator.pushNamed(context, 'result', arguments: product),
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
