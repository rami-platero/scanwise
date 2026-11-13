import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../provider/product_provider.dart';
import '../services/notification_service.dart';
import '../services/product_service.dart';
import '../utils/format_util.dart';

/// Loading screen while the photo (or barcode) gets analyzed.
/// The actual photo/barcode is real (from camera_page/barcode_page), but
/// there's no real recognition service yet - the "analysis" is simulated
/// with a Timer and always returns the same sample guess.
class IdentifyingPage extends StatefulWidget {
  const IdentifyingPage({super.key});

  @override
  State<IdentifyingPage> createState() => _IdentifyingPageState();
}

class _IdentifyingPageState extends State<IdentifyingPage> {
  /// Steps that get checked off to show the user it's making progress.
  final List<String> _steps = const [
    'Procesando la imagen',
    'Buscando la categoria',
    'Comparando con productos conocidos',
  ];

  int _currentStep = 0;
  Timer? _timer;
  bool _started = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start(String? photoPath, String? barcodeValue) {
    if (_started) return;
    _started = true;

    _timer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (_currentStep < _steps.length - 1) {
        setState(() => _currentStep++);
      } else {
        timer.cancel();
        _goToNextPage(photoPath, barcodeValue);
      }
    });
  }

  /// Whether the picked item needs extra photos decides what happens
  /// next: if it doesn't, it's confirmed and saved (CREATE) right away;
  /// otherwise it goes to the guidance screen first, and saving happens
  /// once those photos are done. Either way, the real photo/barcode
  /// travels along with the (still mocked) guess.
  Future<void> _goToNextPage(String? photoPath, String? barcodeValue) async {
    final Product guess = productProvider.firstGuess().copyWith(
      photoPath: photoPath,
      barcodeValue: barcodeValue,
    );

    final bool needsGuidance =
        productProvider.guidanceStepsFor(guess.scenarioId).isNotEmpty;

    if (needsGuidance) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, 'guidance', arguments: guess);
      return;
    }

    await _saveAndShowResult(productProvider.confirmedFor(guess));
  }

  Future<void> _saveAndShowResult(Product confirmed) async {
    try {
      final Product saved = await productService.create(confirmed);
      await _notifyIdentified(saved);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, 'result', arguments: saved);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el producto: $error')),
      );
      Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final Object? arguments = ModalRoute.of(context)?.settings.arguments;
    final Map<String, dynamic> args =
        arguments is Map<String, dynamic> ? arguments : const {};
    final String? photoPath = args['photoPath'] as String?;
    final String? barcodeValue = args['barcodeValue'] as String?;

    // Timer can only be started once the route arguments are available.
    _start(photoPath, barcodeValue);

    return Scaffold(
      appBar: AppBar(title: const Text('Identificando')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (photoPath != null) _photoPreview(photoPath),
            if (barcodeValue != null) _barcodeChip(barcodeValue),
            const CircularProgressIndicator(),
            const SizedBox(height: 32),
            Text(
              'Analizando la foto...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            ..._stepList(),
          ],
        ),
      ),
    );
  }

  Widget _photoPreview(String photoPath) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(photoPath),
          height: 160,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _barcodeChip(String barcodeValue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Chip(label: Text('Codigo: $barcodeValue')),
    );
  }

  List<Widget> _stepList() {
    return List<Widget>.generate(_steps.length, (int i) {
      final bool done = i < _currentStep;
      final bool active = i == _currentStep;

      return ListTile(
        dense: true,
        leading: Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? Colors.green : Colors.grey,
        ),
        title: Text(
          _steps[i],
          style: TextStyle(
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active || done ? null : Colors.grey,
          ),
        ),
      );
    });
  }
}
