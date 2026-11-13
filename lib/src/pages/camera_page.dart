import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Screen for capturing the initial photo.
/// Uses image_picker to open the phone's real camera (or gallery) and
/// get an actual photo file - there's no live preview widget here, the
/// native camera app handles that part.
class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _lastPhoto;
  bool _busy = false;

  /// Null while we haven't asked yet, true/false once we have an answer.
  /// Requested as soon as this screen opens, instead of waiting for the
  /// shutter tap, so the OS prompt doesn't interrupt the capture itself.
  bool? _cameraGranted;

  /// Opens the real camera right away the first time permission comes
  /// back granted, so tapping "Abrir camara" on Home doesn't need a
  /// second tap on the shutter here. Stays false after a cancelled shot
  /// so this screen doesn't loop reopening the camera on its own.
  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final PermissionStatus status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _cameraGranted = status.isGranted);

    if (status.isGranted && !_autoOpened) {
      _autoOpened = true;
      _capture(ImageSource.camera);
    }
  }

  Future<void> _capture(ImageSource source) async {
    if (_busy) return;

    // Gallery doesn't need the camera permission; only guard the shutter.
    if (source == ImageSource.camera && _cameraGranted != true) {
      _showPermissionNotice();
      return;
    }

    setState(() => _busy = true);

    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );

      if (!mounted) return;

      if (photo == null) {
        setState(() => _busy = false);
        return;
      }

      setState(() {
        _lastPhoto = photo;
        _busy = false;
      });

      Navigator.pushNamed(
        context,
        'identifying',
        arguments: {'photoPath': photo.path},
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la camara: $error')),
      );
    }
  }

  void _showPermissionNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Falta el permiso de camara'),
        action: SnackBarAction(
          label: 'Ajustes',
          onPressed: openAppSettings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Foto del producto'),
      ),
      body: Column(
        children: [
          if (_cameraGranted == false) _permissionBanner(),
          Expanded(child: _preview()),
          _controls(context),
        ],
      ),
    );
  }

  Widget _permissionBanner() {
    return MaterialBanner(
      backgroundColor: Colors.amber.shade100,
      content: const Text(
        'Sin acceso a la camara. Podes elegir fotos de la galeria, o '
        'habilitar el permiso para sacar una nueva.',
      ),
      actions: [
        TextButton(
          onPressed: _requestCameraPermission,
          child: const Text('Reintentar'),
        ),
        TextButton(onPressed: openAppSettings, child: const Text('Ajustes')),
      ],
    );
  }

  Widget _preview() {
    if (_busy) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_lastPhoto != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(File(_lastPhoto!.path), fit: BoxFit.contain),
          ),
        ),
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 48),
        child: Text(
          'La camara se abre sola. Si la cerraste sin sacar nada, toca el '
          'boton para volver a intentar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
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
            onPressed: () => _capture(ImageSource.gallery),
          ),
          // Real shutter: opens the device's camera app via image_picker.
          // By now permission was already requested in initState, so this
          // should just work without an OS prompt interrupting the tap.
          GestureDetector(
            onTap: () => _capture(ImageSource.camera),
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
