import 'package:flutter/material.dart';

/// Alternativa de identificacion para productos con su caja original.
class BarcodePage extends StatelessWidget {
  const BarcodePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Codigo de barras'),
      ),
      body: Column(
        children: [
          Expanded(child: _scanArea()),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  'Apunta al codigo de barras de la caja',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, 'identifying'),
                  icon: const Icon(Icons.check),
                  label: const Text('Simular lectura'),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, 'camera'),
                  child: const Text('Mi producto no tiene caja'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanArea() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        height: 180,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white70, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          // Linea de lectura, solo decorativa.
          child: Container(height: 2, color: Colors.redAccent),
        ),
      ),
    );
  }
}
