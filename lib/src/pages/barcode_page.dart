import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// Alternative identification method for products with their original box.
/// Uses mobile_scanner for a real, live camera feed that actually detects
/// barcodes/QR codes.
class BarcodePage extends StatefulWidget {
  const BarcodePage({super.key});

  @override
  State<BarcodePage> createState() => _BarcodePageState();
}

class _BarcodePageState extends State<BarcodePage> {
  MobileScannerController? _controller;

  /// Null while we haven't asked yet, true/false once we have an answer.
  /// Requested as soon as this screen opens, before the scanner widget
  /// (and its own lazy request) ever gets built.
  bool? _cameraGranted;

  /// Avoids firing the navigation more than once per successful scan.
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final PermissionStatus status = await Permission.camera.request();
    if (!mounted) return;

    setState(() {
      _cameraGranted = status.isGranted;
      if (status.isGranted) {
        _controller = MobileScannerController(
          formats: const [BarcodeFormat.all],
        );
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    final String? code = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;

    if (code == null || code.isEmpty) return;

    _handled = true;
    _controller?.stop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Codigo detectado: $code')),
    );

    Navigator.pushReplacementNamed(
      context,
      'identifying',
      arguments: {'barcodeValue': code},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Codigo de barras'),
        actions: [
          if (_controller != null)
            IconButton(
              icon: const Icon(Icons.flash_on),
              tooltip: 'Flash',
              onPressed: () => _controller!.toggleTorch(),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _scannerArea()),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  'Apunta al codigo de barras de la caja',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, 'camera'),
                  child: const Text(
                    'Mi producto no tiene caja',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scannerArea() {
    if (_cameraGranted == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_cameraGranted == false) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography, color: Colors.white54, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Sin acceso a la camara para escanear el codigo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _requestCameraPermission,
                    child: const Text('Reintentar'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: openAppSettings,
                    child: const Text('Ajustes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        _scanFrame(),
      ],
    );
  }

  Widget _scanFrame() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        height: 180,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white70, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
