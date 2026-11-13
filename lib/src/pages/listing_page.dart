import 'package:flutter/material.dart';

import '../models/product.dart';
import '../provider/product_provider.dart';
import '../services/product_service.dart';
import '../utils/format_util.dart';

/// Listing data built from the product's info.
/// The user can edit it, save it (UPDATE) and then copy/share it.
class ListingPage extends StatefulWidget {
  const ListingPage({super.key});

  @override
  State<ListingPage> createState() => _ListingPageState();
}

class _ListingPageState extends State<ListingPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  /// Fields are filled in only once, from the product passed via the route.
  bool _loaded = false;
  bool _saving = false;

  /// Kept so the save action knows which row to update.
  Product? _product;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _loadProduct(Product product) {
    if (_loaded) return;

    _product = product;
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
            // Category comes from the identification step, not editable here.
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveChanges,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
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
                  child: OutlinedButton.icon(
                    // The native share sheet would be wired in here.
                    onPressed: () => _showMessage('Abriendo menu de compartir'),
                    icon: const Icon(Icons.share),
                    label: const Text('Compartir'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Persists the edited title, description and price back to the
  /// product's row in Supabase (UPDATE).
  Future<void> _saveChanges() async {
    final Product? product = _product;
    if (product == null || product.id == null) {
      _showMessage('Este producto todavia no se guardo en la base de datos');
      return;
    }

    final double? price = double.tryParse(_priceController.text);
    if (price == null) {
      _showMessage('El precio no es un numero valido');
      return;
    }

    setState(() => _saving = true);

    try {
      await productService.updateListing(
        product.id!,
        name: _titleController.text,
        description: _descriptionController.text,
        priceMin: price,
        priceMax: price,
      );
      if (!mounted) return;
      _showMessage('Cambios guardados');
    } catch (error) {
      if (!mounted) return;
      _showMessage('No se pudo guardar: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}
