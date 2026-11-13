import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../provider/product_provider.dart';
import '../services/notification_service.dart';
import '../services/product_service.dart';
import '../utils/format_util.dart';

/// Interactive guidance: when the first guess isn't enough, the app asks
/// for specific extra photos until the exact product version gets
/// confirmed. How many steps (if any) depends on the item - see
/// fake_catalog.dart - so this screen is only reached when there's at
/// least one.
class GuidancePage extends StatefulWidget {
  const GuidancePage({super.key});

  @override
  State<GuidancePage> createState() => _GuidancePageState();
}

class _GuidancePageState extends State<GuidancePage> {
  /// Resolved once the product (and its scenario) is known from the
  /// route arguments - see _initSteps.
  List<Map<String, String>>? _steps;
  final List<bool> _captured = [];

  /// Avoids a double tap while the product is being saved.
  bool _saving = false;

  /// Only the first build has the route arguments available, so the
  /// steps are resolved lazily here instead of in initState.
  void _initSteps(Product product) {
    if (_steps != null) return;

    final List<Map<String, String>> steps =
        productProvider.guidanceStepsFor(product.scenarioId);
    _steps = steps;
    _captured.addAll(List<bool>.filled(steps.length, false));
  }

  int get _capturedCount => _captured.where((done) => done).length;

  bool get _allCaptured => _capturedCount == (_steps?.length ?? 0);

  @override
  Widget build(BuildContext context) {
    // The product comes from the previous screen.
    final Object? arguments = ModalRoute.of(context)?.settings.arguments;
    final Product product =
        arguments is Product ? arguments : productProvider.firstGuess();

    _initSteps(product);

    return Scaffold(
      appBar: AppBar(title: const Text('Falta un poco mas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _partialResult(context, product),
          const SizedBox(height: 24),
          Text(
            'Fotos que faltan',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._stepTiles(context),
        ],
      ),
      bottomNavigationBar: _confirmBar(context, product),
    );
  }

  /// What the app could already recognize from the first photo.
  Widget _partialResult(BuildContext context, Product product) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reconocimos esto',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (product.catalogImageAsset != null || product.photoPath != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  // Prefer the curated cover when there is one; otherwise
                  // this is the user's own real photo.
                  child: product.catalogImageAsset != null
                      ? Image.asset(product.catalogImageAsset!, fit: BoxFit.cover)
                      : Image.file(File(product.photoPath!), fit: BoxFit.cover),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Categoria: ${product.category}')),
                Chip(label: Text('Marca: ${product.brand}')),
                const Chip(label: Text('Modelo: sin confirmar')),
              ],
            ),
            const SizedBox(height: 16),
            Text('Certeza actual: ${percent(product.confidence)}'),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: product.confidence),
          ],
        ),
      ),
    );
  }

  List<Widget> _stepTiles(BuildContext context) {
    final List<Map<String, String>> steps = _steps ?? const [];

    return List<Widget>.generate(steps.length, (int i) {
      final bool done = _captured[i];

      return Card(
        child: ListTile(
          leading: Icon(
            done ? Icons.check_circle : Icons.photo_camera_outlined,
            color: done ? Colors.green : null,
          ),
          title: Text(steps[i]['title'] ?? ''),
          subtitle: Text(steps[i]['hint'] ?? ''),
          trailing: done
              ? TextButton(
                  onPressed: () => setState(() => _captured[i] = false),
                  child: const Text('Repetir'),
                )
              : FilledButton(
                  onPressed: () => setState(() => _captured[i] = true),
                  child: const Text('Sacar'),
                ),
        ),
      );
    });
  }

  Widget _confirmBar(BuildContext context, Product product) {
    final int total = _steps?.length ?? 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_capturedCount de $total fotos listas'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                // Only enabled once every photo is in.
                onPressed: (_allCaptured && !_saving)
                    ? () => _confirmModel(product)
                    : null,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined),
                label: Text(_saving ? 'Guardando...' : 'Confirmar modelo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// With the extra photos the confidence goes up and the exact model is
  /// known. This is where the product actually gets saved (CREATE).
  Future<void> _confirmModel(Product product) async {
    final Product confirmed = productProvider.confirmedFor(product);

    setState(() => _saving = true);

    try {
      final Product saved = await productService.create(confirmed);
      await _notifyIdentified(saved);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, 'result', arguments: saved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el producto: $error')),
      );
    }
  }

  /// Logs an "identification complete" notification for this product.
  /// Best-effort: a failure here should never block the main CRUD flow.
  Future<void> _notifyIdentified(Product saved) async {
    try {
      await notificationService.create(
        title: 'Identificacion completada',
        body: '${saved.name} fue identificado con ${percent(saved.confidence)} '
            'de certeza.',
        icon: saved.icon,
        productId: saved.id,
      );
    } catch (_) {
      // Non-critical: the product is already saved either way.
    }
  }
}
