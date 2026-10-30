import 'package:flutter/material.dart';

/// Pantalla de captura de la foto inicial.
/// Por ahora el visor es un marco de prueba: cuando se agregue el paquete
/// de camara, el Container negro se reemplaza por la vista previa real.
class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  bool _flashOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Foto del producto'),
        actions: [
          IconButton(
            icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
            tooltip: 'Flash',
            onPressed: () => setState(() => _flashOn = !_flashOn),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _viewfinder()),
          _controls(context),
        ],
      ),
    );
  }

  Widget _viewfinder() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            margin: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Encuadra el producto completo dentro del marco',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            color: Colors.white,
            iconSize: 28,
            tooltip: 'Elegir de la galeria',
            onPressed: () => Navigator.pushNamed(context, 'identifying'),
          ),
          // Disparador: lleva a la pantalla de analisis.
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, 'identifying'),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white24, width: 6),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            color: Colors.white,
            iconSize: 28,
            tooltip: 'Escanear codigo de barras',
            onPressed: () => Navigator.pushNamed(context, 'barcode'),
          ),
        ],
      ),
    );
  }
}
