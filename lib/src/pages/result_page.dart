import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../provider/product_provider.dart';
import '../services/product_service.dart';
import '../utils/format_util.dart';
import '../utils/icon_string_util.dart';

/// Already-identified product: shows the recognized data and the
/// actions that can be taken on it.
class ResultPage extends StatefulWidget {
  const ResultPage({super.key});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final Object? arguments = ModalRoute.of(context)?.settings.arguments;
    final Product product =
        arguments is Product ? arguments : productProvider.history().first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Producto identificado'),
        actions: [
          IconButton(
            icon: _deleting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                : Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
            tooltip: 'Eliminar',
            onPressed: _deleting ? null : () => _confirmDelete(product),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(context, product),
          const SizedBox(height: 16),
          _dataCard(context, product),
          const SizedBox(height: 16),
          _priceCard(context, product),
          const SizedBox(height: 24),
          _actions(context, product),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, Product product) {
    return Row(
      children: [
        _thumbnail(context, product),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text('${product.brand} - ${product.category}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.verified, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('Certeza ${percent(product.confidence)}'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Prefers the catalog's cover once identification found a match, then
  /// the real photo taken with the camera (now persisted - see
  /// ProductService._persistPhoto), then the generic icon as a last
  /// resort.
  Widget _thumbnail(BuildContext context, Product product) {
    final BorderRadius radius = BorderRadius.circular(12);

    if (product.catalogImageAsset != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          product.catalogImageAsset!,
          width: 88,
          height: 88,
          fit: BoxFit.cover,
        ),
      );
    }

    if (product.photoPath != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(product.photoPath!),
          width: 88,
          height: 88,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: radius,
      ),
      child: Center(child: getIcon(product.icon, size: 40)),
    );
  }

  Widget _dataCard(BuildContext context, Product product) {
    return Card(
      child: Column(
        children: [
          _dataRow('Categoria', product.category),
          const Divider(height: 1),
          _dataRow('Marca', product.brand),
          const Divider(height: 1),
          _dataRow(
            'Modelo exacto',
            product.model.isEmpty ? 'Sin confirmar' : product.model,
          ),
          const Divider(height: 1),
          _dataRow('Escaneado', product.scannedAt),
        ],
      ),
    );
  }

  Widget _dataRow(String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(value),
    );
  }

  Widget _priceCard(BuildContext context, Product product) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Precio de referencia',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${money(product.priceMin)} - ${money(product.priceMax)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            const Text('Segun publicaciones parecidas'),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, Product product) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              'price',
              arguments: product,
            ),
            icon: const Icon(Icons.trending_up),
            label: const Text('Comparar precios'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              'listing',
              arguments: product,
            ),
            icon: const Icon(Icons.sell_outlined),
            label: const Text('Generar publicacion'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, 'condition'),
            icon: const Icon(Icons.compare),
            label: const Text('Documentar el estado'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => Navigator.pushNamed(context, 'guidance'),
          icon: const Icon(Icons.help_outline),
          label: const Text('No es este producto'),
        ),
      ],
    );
  }

  /// Works the same regardless of which sample product this is (Silent
  /// Hill, a console, or a real future AI result) - delete just needs
  /// the row's id, nothing scenario-specific.
  Future<void> _confirmDelete(Product product) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${product.name}" del historial?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);

    try {
      await productService.delete(product);
      if (!mounted) return;
      // The product is gone - back to Home instead of leaving it
      // sitting on a route that no longer makes sense.
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $error')),
      );
    }
  }
}
