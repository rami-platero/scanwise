import 'package:flutter/material.dart';

import '../models/product.dart';
import '../provider/product_provider.dart';
import '../utils/format_util.dart';

/// Guia interactiva: cuando la certeza es baja, la app pide fotos
/// concretas (logo, panel trasero, numero de serie) hasta confirmar
/// la version exacta del producto.
class GuidancePage extends StatefulWidget {
  const GuidancePage({super.key});

  @override
  State<GuidancePage> createState() => _GuidancePageState();
}

class _GuidancePageState extends State<GuidancePage> {
  final List<Map<String, String>> _steps = productProvider.guidanceSteps();

  /// Marca que fotos ya se sacaron.
  final List<bool> _captured = [];

  @override
  void initState() {
    super.initState();
    _captured.addAll(List<bool>.filled(_steps.length, false));
  }

  int get _capturedCount => _captured.where((done) => done).length;

  bool get _allCaptured => _capturedCount == _steps.length;

  @override
  Widget build(BuildContext context) {
    // El producto llega desde la pantalla anterior.
    final Object? arguments = ModalRoute.of(context)?.settings.arguments;
    final Product product =
        arguments is Product ? arguments : productProvider.firstGuess();

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

  /// Lo que la app ya pudo reconocer con la primera foto.
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
    return List<Widget>.generate(_steps.length, (int i) {
      final bool done = _captured[i];

      return Card(
        child: ListTile(
          leading: Icon(
            done ? Icons.check_circle : Icons.photo_camera_outlined,
            color: done ? Colors.green : null,
          ),
          title: Text(_steps[i]['title'] ?? ''),
          subtitle: Text(_steps[i]['hint'] ?? ''),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_capturedCount de ${_steps.length} fotos listas'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                // Se habilita solo cuando estan todas las fotos.
                onPressed: _allCaptured ? () => _confirmModel(product) : null,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Confirmar modelo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Con las fotos adicionales la certeza sube y ya hay modelo exacto.
  void _confirmModel(Product product) {
    final Product confirmed = product.copyWith(
      name: 'Sony WH-1000XM4',
      model: 'WH-1000XM4',
      confidence: 0.97,
      priceMin: 130,
      priceMax: 205,
      description:
          'Auriculares inalambricos Sony WH-1000XM4 con cancelacion de ruido '
          'activa, bluetooth y estuche rigido.',
    );

    Navigator.pushReplacementNamed(context, 'result', arguments: confirmed);
  }
}
