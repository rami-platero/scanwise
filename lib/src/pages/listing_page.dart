import 'package:flutter/material.dart';

import '../models/product.dart';
import '../provider/product_provider.dart';
import '../utils/format_util.dart';

/// Datos de la publicacion armados con la informacion del producto.
/// El usuario los puede editar antes de copiarlos o compartirlos.
class ListingPage extends StatefulWidget {
  const ListingPage({super.key});

  @override
  State<ListingPage> createState() => _ListingPageState();
}

class _ListingPageState extends State<ListingPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  /// Se llenan los campos una sola vez, con los datos que llegan por la ruta.
  bool _loaded = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _loadProduct(Product product) {
    if (_loaded) return;

    _titleController.text = product.model.isEmpty
        ? '${product.brand} ${product.name}'
        : '${product.brand} ${product.model}';
    _descriptionController.text = product.description.isEmpty
        ? '${product.name} de la marca ${product.brand}. En buen estado, '
            'funcionando correctamente.'
        : product.description;
    _priceController.text = product.suggestedPrice.toStringAsFixed(0);
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final Object? arguments = ModalRoute.of(context)?.settings.arguments;
    final Product product =
        arguments is Product ? arguments : productProvider.history().first;

    _loadProduct(product);

    return Scaffold(
      appBar: AppBar(title: const Text('Datos de la publicacion')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Titulo',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            // La categoria la define la identificacion, no se edita.
            readOnly: true,
            controller: TextEditingController(text: product.category),
            decoration: const InputDecoration(
              labelText: 'Categoria',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Descripcion',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Precio sugerido',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rango de referencia: ${money(product.priceMin)} - '
            '${money(product.priceMax)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      bottomNavigationBar: _bottomActions(context),
    );
  }

  Widget _bottomActions(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showMessage('Datos copiados'),
                icon: const Icon(Icons.copy),
                label: const Text('Copiar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                // Aca va a ir el menu de compartir del telefono.
                onPressed: () => _showMessage('Abriendo menu de compartir'),
                icon: const Icon(Icons.share),
                label: const Text('Compartir'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}
