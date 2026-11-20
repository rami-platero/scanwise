import 'package:flutter/material.dart';

/// Shown when a screen that needs a product is opened without one.
/// Shouldn't happen in the normal flow - it's a guard against a bad
/// deep link or a route opened directly - so it just offers a way back.
class MissingProductScaffold extends StatelessWidget {
  const MissingProductScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Producto')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No hay un producto para mostrar.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
