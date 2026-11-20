import 'package:flutter/material.dart';

import '../models/product.dart';
import '../widgets/missing_product_scaffold.dart';
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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
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
    final Product? product = arguments is Product ? arguments : null;
    if (product == null) return const MissingProductScaffold();

    _loadProduct(product);

    return Scaffold(
      appBar: AppBar(title: const Text('Datos de la publicacion')),
      body: Form(
        key: _formKey,
        // Shows the error under a field as soon as the user has touched
        // it, instead of staying silent until the save button is hit.
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Titulo',
                helperText: 'Como lo va a ver el comprador',
                border: OutlineInputBorder(),
              ),
              validator: _validateTitle,
            ),
            const SizedBox(height: 8),
            TextFormField(
              // Category comes from the identification step, not editable.
              readOnly: true,
              initialValue: product.category,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: 600,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripcion',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: _validateDescription,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Precio sugerido',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              validator: _validatePrice,
            ),
            const SizedBox(height: 8),
            Text(
              'Rango de referencia: ${money(product.priceMin)} - '
              '${money(product.priceMax)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
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

  String? _validateTitle(String? value) {
    final String title = (value ?? '').trim();
    if (title.isEmpty) return 'Poné un titulo para la publicacion';
    if (title.length < 5) return 'Muy corto, usá al menos 5 caracteres';
    return null;
  }

  String? _validateDescription(String? value) {
    final String description = (value ?? '').trim();
    if (description.isEmpty) return 'Describí el producto y su estado';
    if (description.length < 15) {
      return 'Muy corta, contá al menos el estado en el que esta';
    }
    return null;
  }

  /// Accepts "1234", "1234.50" and "1234,50" - a comma is what most
  /// Spanish-locale keyboards give for the decimal separator.
  String? _validatePrice(String? value) {
    final String raw = (value ?? '').trim().replaceAll(',', '.');
    if (raw.isEmpty) return 'Poné un precio';

    final double? price = double.tryParse(raw);
    if (price == null) return 'Tiene que ser un numero (ej. 15000)';
    if (price <= 0) return 'El precio tiene que ser mayor a 0';
    if (price > 99999999) return 'Ese precio es demasiado alto';
    return null;
  }

  double get _parsedPrice =>
      double.parse(_priceController.text.trim().replaceAll(',', '.'));

  /// Persists the edited title, description and price back to the
  /// product's row in Supabase (UPDATE).
  Future<void> _saveChanges() async {
    final Product? product = _product;
    if (product == null || product.id == null) {
      _showMessage('Este producto todavia no se guardo en la base de datos');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showMessage('Revisá los campos marcados en rojo');
      return;
    }

    final double price = _parsedPrice;

    setState(() => _saving = true);

    try {
      await productService.updateListing(
        product.id!,
        name: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
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
