import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../widgets/missing_product_scaffold.dart';
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

  /// Pops everything back to Home in one shot, instead of one screen at
  /// a time. Without this, the system back button would step back
  /// through Camera (which still shows the photo it took, sitting idle)
  /// since identifying/guidance replace each other but never replace
  /// Camera itself - confusing after the scan is already done and saved.
  void _goHome(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final Object? arguments = ModalRoute.of(context)?.settings.arguments;
    final Product? product = arguments is Product ? arguments : null;
    if (product == null) return const MissingProductScaffold();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _goHome(context);
      },
      child: Scaffold(
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
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.icon(
              onPressed: () => _goHome(context),
              icon: const Icon(Icons.check),
              label: const Text('Listo, volver al inicio'),
            ),
          ),
        ),
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
              Text(product.name, style: Theme.of(context).textTheme.titleLarge),
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
    // Only rows with something real in them, so an item whose region or
    // edition couldn't be read doesn't show a column of "Sin confirmar".
    final List<Widget> rows = [
      _dataRow('Tipo', product.category),
      if (product.platform.isNotEmpty) _dataRow('Plataforma', product.platform),
      _dataRow('Marca', product.brand),
      if (product.region.isNotEmpty) _dataRow('Region', product.region),
      if (product.edition.isNotEmpty) _dataRow('Edicion', product.edition),
      _dataRow(
        'Codigo de catalogo',
        product.model.isEmpty ? 'No visible en la foto' : product.model,
      ),
      if (product.completeness.isNotEmpty)
        _dataRow('Incluye', _completenessLabel(product.completeness)),
      _dataRow('Escaneado', product.scannedAt),
    ];

    return Card(
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            rows[i],
          ],
        ],
      ),
    );
  }

  String _completenessLabel(String value) {
    switch (value) {
      case 'complete_in_box':
        return 'Completo en caja';
      case 'box_and_game_no_manual':
        return 'Caja y juego, sin manual';
      case 'game_only':
        return 'Solo el juego';
      case 'console_only':
        return 'Solo la consola';
      case 'console_with_accessories':
        return 'Consola con accesorios';
      default:
        return 'Sin determinar';
    }
  }

  Widget _dataRow(String label, String value) {
    return ListTile(dense: true, title: Text(label), trailing: Text(value));
  }

  Widget _priceCard(BuildContext context, Product product) {
    // Both providers can legitimately come back empty right after saving
    // (eBay account in review, MercadoLibre not configured yet, no
    // network, ...). "$0 - $0" would read as broken, so this shows an
    // honest pending state instead and points at the retry button below.
    final bool hasPriceData = product.priceMax > 0;

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
            if (hasPriceData) ...[
              Text(
                '${money(product.priceMin)} - ${money(product.priceMax)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(_priceSourceLabel(product.priceSource)),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.hourglass_empty, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Todavia no se pudo conseguir un precio. Toca '
                      '"Comparar precios" para reintentar.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Honesty matters here: a real marketplace figure and the AI's own
  /// guess shouldn't look the same.
  String _priceSourceLabel(String source) {
    if (source.isEmpty) return 'Segun publicaciones parecidas';
    if (source == 'IA (estimado)') {
      return 'Estimacion de la IA - no proviene de una publicacion real, '
          'usala como referencia aproximada';
    }
    return 'Segun publicaciones activas en $source';
  }

  Widget _actions(BuildContext context, Product product) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, 'price', arguments: product),
            icon: const Icon(Icons.trending_up),
            label: const Text('Comparar precios'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, 'listing', arguments: product),
            icon: const Icon(Icons.sell_outlined),
            label: const Text('Generar publicacion'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          // Re-running the whole scan is the honest option here: the
          // guidance screen needs a live identification session, which
          // no longer exists once the product has been saved.
          onPressed: () => Navigator.pushReplacementNamed(context, 'camera'),
          icon: const Icon(Icons.help_outline),
          label: const Text('No es este producto, escanear de nuevo'),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $error')));
    }
  }
}
