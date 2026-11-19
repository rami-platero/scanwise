import 'dart:io';

import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/market_listing.dart';
import '../models/product.dart';
import '../models/recognition_result.dart';
import '../models/scan_session.dart';
import '../provider/mock_recognition.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';
import '../services/price_comparison_service.dart';
import '../services/product_service.dart';
import '../utils/format_util.dart';

/// Runs one identification pass and routes onward based on the outcome.
///
/// Three possible endings:
///   - Not a game/console  -> rejection screen, nothing is saved.
///   - Needs more photos   -> the guidance screen, with Gemini's own
///                            concrete photo requests.
///   - Identified          -> price it on eBay, save it, show the result.
class IdentifyingPage extends StatefulWidget {
  const IdentifyingPage({super.key});

  @override
  State<IdentifyingPage> createState() => _IdentifyingPageState();
}

enum _Stage { analyzing, pricing, saving, rejected, failed }

class _IdentifyingPageState extends State<IdentifyingPage> {
  _Stage _stage = _Stage.analyzing;
  String? _errorMessage;
  RecognitionResult? _rejected;
  ScanSession? _session;
  bool _started = false;

  /// Route arguments only exist once build runs, so the work is kicked
  /// off from there - but deferred to after the frame, since the first
  /// thing these methods do is setState, which isn't allowed mid-build.
  void _startOnce(ScanSession session, RecognitionResult? preResolved) {
    if (_started) return;
    _started = true;
    _session = session;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // "Guardar asi" on the guidance screen sends back the result it
      // already has, so there's no reason to pay for another model call
      // - jump straight to pricing and saving.
      if (preResolved != null) {
        _priceAndSave(session, preResolved);
        return;
      }

      _run(session);
    });
  }

  Future<void> _run(ScanSession session) async {
    try {
      final RecognitionResult result = useMockRecognition
          ? await mockIdentify(session)
          : await geminiService.identify(session);

      if (!mounted) return;

      // Out of scope: not a physical game, console or accessory.
      if (!result.isSupported) {
        setState(() {
          _stage = _Stage.rejected;
          _rejected = result;
        });
        return;
      }

      // Still unsure, and there's room for another round of photos.
      if (result.needsMorePhotos && !session.isFinalRound) {
        Navigator.pushReplacementNamed(
          context,
          'guidance',
          arguments: {'session': session, 'result': result},
        );
        return;
      }

      await _priceAndSave(session, result);
    } on GeminiException catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _errorMessage = 'Algo salio mal al identificar: $error';
      });
    }
  }

  Future<void> _priceAndSave(
    ScanSession session,
    RecognitionResult result,
  ) async {
    setState(() => _stage = _Stage.pricing);

    // A failed price lookup shouldn't block saving the product, so this
    // variant swallows its own errors and just returns null.
    final MarketPriceReport? prices = await priceComparisonService
        .trySearchSimilar(query: result.ebayQuery, isConsole: result.isConsole);

    if (!mounted) return;

    final Product product = Product.fromRecognition(
      result,
      prices: prices,
      photoPath: session.primaryImagePath,
      barcodeValue: session.barcode,
    );

    final Product? existing = await productService.findPossibleDuplicate(
      name: product.name,
      platform: product.platform,
    );

    if (!mounted) return;

    if (existing != null) {
      final bool proceed = await _confirmDuplicate(existing);
      if (!mounted) return;
      if (!proceed) {
        // The user said this was an accidental re-scan - nothing to
        // save, so there's no reason to leave them stranded here.
        Navigator.popUntil(context, (route) => route.isFirst);
        return;
      }
    }

    setState(() => _stage = _Stage.saving);

    try {
      final Product saved = await productService.create(product);
      await _notifyIdentified(saved);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, 'result', arguments: saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _errorMessage = 'No se pudo guardar el producto: $error';
      });
    }
  }

  /// Asks before saving on top of something that looks like it's
  /// already in the user's history. Defaults to "cancel" if dismissed
  /// without an explicit choice.
  Future<bool> _confirmDuplicate(Product existing) async {
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Ya tenes algo parecido'),
        content: Text(
          'Ya escaneaste "${existing.name}" '
          '(${existing.platform.isEmpty ? existing.category : existing.platform}) '
          'el ${existing.scannedAt}. Si es una copia distinta, segui '
          'igual; si fue sin querer, cancela.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar igual'),
          ),
        ],
      ),
    );

    return proceed ?? false;
  }

  /// Best-effort log entry; never blocks the main flow.
  Future<void> _notifyIdentified(Product saved) async {
    try {
      await notificationService.create(
        title: 'Identificacion completada',
        body:
            '${saved.name} fue identificado con '
            '${percent(saved.confidence)} de certeza.',
        icon: saved.icon,
        productId: saved.id,
      );
    } catch (_) {
      // The product is already saved either way.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScanSession session = _resolveSession(context);
    _startOnce(session, _resolvePreResolved(context));

    return Scaffold(
      appBar: AppBar(
        title: Text(session.round > 1 ? 'Reanalizando' : 'Identificando'),
      ),
      body: SafeArea(child: _body(context, session)),
    );
  }

  Widget _body(BuildContext context, ScanSession session) {
    switch (_stage) {
      case _Stage.rejected:
        return _rejectedView(context);
      case _Stage.failed:
        return _failedView(context);
      default:
        return _progressView(context, session);
    }
  }

  Widget _progressView(BuildContext context, ScanSession session) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _photoStrip(session),
        const SizedBox(height: 24),
        Center(
          child: Text(
            session.round > 1
                ? 'Revisando con las fotos nuevas...'
                : 'Analizando la foto...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 24),
        _step(
          context,
          label: useMockRecognition
              ? 'Identificando (modo demo)'
              : 'Identificando el producto con IA',
          done: _stage != _Stage.analyzing,
          active: _stage == _Stage.analyzing,
        ),
        _step(
          context,
          label: 'Buscando precios de referencia',
          done: _stage == _Stage.saving,
          active: _stage == _Stage.pricing,
        ),
        _step(
          context,
          label: 'Guardando en tu historial',
          done: false,
          active: _stage == _Stage.saving,
        ),
        if (session.barcode != null) ...[
          const SizedBox(height: 16),
          Center(child: Chip(label: Text('Codigo: ${session.barcode}'))),
        ],
      ],
    );
  }

  Widget _step(
    BuildContext context, {
    required String label,
    required bool done,
    required bool active,
  }) {
    return ListTile(
      dense: true,
      leading: done
          ? const Icon(Icons.check_circle, color: Colors.green)
          : active
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active || done ? null : Colors.grey,
        ),
      ),
    );
  }

  /// Every photo gathered so far, so the user can see what the model is
  /// actually looking at on a second pass.
  Widget _photoStrip(ScanSession session) {
    if (session.imagePaths.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: session.imagePaths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int i) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(session.imagePaths[i]),
              width: 140,
              height: 140,
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }

  /// Shown when the photo isn't a game or console at all.
  Widget _rejectedView(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String reason = _rejected?.rejectionReason ?? '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 56, color: colors.error),
            const SizedBox(height: 16),
            Text(
              'Esto no parece un juego ni una consola',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              reason.isEmpty
                  ? 'ScanWise solo identifica videojuegos fisicos, consolas '
                        'y accesorios de consola.'
                  : reason,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Proba sacando la foto del juego o de la consola, con buena '
              'luz y de frente.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, 'camera'),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Sacar otra foto'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failedView(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: colors.error),
            const SizedBox(height: 16),
            Text(
              'No se pudo identificar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Error desconocido.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                final ScanSession? session = _session;
                if (session == null) return;
                setState(() {
                  _stage = _Stage.analyzing;
                  _errorMessage = null;
                });
                _run(session);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Set when the caller already has an identification and only wants the
/// pricing + saving half of this screen.
RecognitionResult? _resolvePreResolved(BuildContext context) {
  final Object? arguments = ModalRoute.of(context)?.settings.arguments;
  if (arguments is! Map) return null;

  final Object? result = arguments['skipRecognitionWith'];
  return result is RecognitionResult ? result : null;
}

/// Accepts either a ready-made [ScanSession] (coming back from the
/// guidance screen for another round) or the simple photo/barcode map
/// the camera and barcode screens send for a first pass.
ScanSession _resolveSession(BuildContext context) {
  final Object? arguments = ModalRoute.of(context)?.settings.arguments;

  if (arguments is ScanSession) return arguments;

  if (arguments is Map) {
    final Object? session = arguments['session'];
    if (session is ScanSession) return session;

    final String? photoPath = arguments['photoPath'] as String?;
    final String? barcode = arguments['barcodeValue'] as String?;

    return ScanSession(imagePaths: [?photoPath], barcode: barcode);
  }

  return ScanSession(imagePaths: const []);
}
