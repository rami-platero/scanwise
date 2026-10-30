import 'package:flutter/material.dart';

import '../models/product.dart';
import '../provider/product_provider.dart';
import '../utils/format_util.dart';
import '../utils/icon_string_util.dart';

/// Producto ya identificado: muestra los datos reconocidos y las
/// acciones que se pueden hacer con el.
class ResultPage extends StatelessWidget {
  const ResultPage({super.key});

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
            icon: const Icon(Icons.bookmark_border),
            tooltip: 'Guardar',
            onPressed: () => _showMessage(context, 'Guardado en el historial'),
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
        // Espacio para la foto tomada. Por ahora va el icono del producto.
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: getIcon(product.icon, size: 40)),
        ),
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

  void _showMessage(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}
