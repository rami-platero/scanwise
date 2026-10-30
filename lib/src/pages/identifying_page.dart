import 'dart:async';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../provider/product_provider.dart';

/// Pantalla de espera mientras se analiza la foto.
/// El analisis se simula con un Timer; cuando haya un servicio real,
/// se reemplaza por la llamada a ese servicio.
class IdentifyingPage extends StatefulWidget {
  const IdentifyingPage({super.key});

  @override
  State<IdentifyingPage> createState() => _IdentifyingPageState();
}

class _IdentifyingPageState extends State<IdentifyingPage> {
  /// Pasos que se van marcando para mostrarle al usuario que avanza.
  final List<String> _steps = const [
    'Procesando la imagen',
    'Buscando la categoria',
    'Comparando con productos conocidos',
  ];

  int _currentStep = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (_currentStep < _steps.length - 1) {
        setState(() => _currentStep++);
      } else {
        timer.cancel();
        _goToNextPage();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Si la certeza es alta se muestra el resultado;
  /// si no, se pasa a la guia de fotos adicionales.
  void _goToNextPage() {
    if (!mounted) return;

    final Product product = productProvider.firstGuess();

    Navigator.pushReplacementNamed(
      context,
      product.isExactModel ? 'result' : 'guidance',
      arguments: product,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identificando')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
