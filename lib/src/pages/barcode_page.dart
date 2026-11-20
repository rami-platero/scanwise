import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
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
        // Game cases often carry a second barcode (Code 128/39) for the
        // publisher's internal SKU, next to the retail UPC/EAN one.
        // Scanning for every format lets the scanner lock onto whichever
        // one it sees first - restricting to retail formats makes sure
        // it only ever reports the actual product barcode.
        _controller = MobileScannerController(
          formats: const [
            BarcodeFormat.upcA,
            BarcodeFormat.upcE,
            BarcodeFormat.ean13,
            BarcodeFormat.ean8,
          ],
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
    _showCodeDialog(code);
  }

  // A SnackBar shown right before pushReplacementNamed never actually
  // gets seen - the route (and the SnackBar with it) is gone in the same
  // frame. A dialog that waits for a tap fixes that, and doubles as a
  // way to copy the raw code out for debugging.
  Future<void> _showCodeDialog(String code) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Codigo detectado'),
        content: Row(
          children: [
            Expanded(
              child: Text(code, style: const TextStyle(fontSize: 18)),
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copiar',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Codigo copiado')),
                );
              },
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    // The barcode alone isn't enough to identify an item (there's no
    // product database keyed by GTIN here), but it's a strong extra
    // signal for region/edition. So: grab a photo too, carrying the
    // code along, and send both to the model together.
    Navigator.pushReplacementNamed(
      context,
      'camera',
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
                  'Apunta al codigo de barras de la caja del juego',
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
