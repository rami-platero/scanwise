import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/recognition_result.dart';
import '../models/scan_session.dart';
import '../utils/format_util.dart';
import '../widgets/missing_product_scaffold.dart';

/// Collects the extra photos Gemini asked for.
///
/// The requests aren't a fixed checklist - they're generated per item by
/// the model ("the back of the case, so I can read the catalog code"),
/// so what's listed here changes with what it's looking at and what it
/// still can't determine.
///
/// Once at least one new photo is in, everything (old photos + new ones)
/// goes back for another pass. The user can also stop early and keep the
/// identification as it stands.
class GuidancePage extends StatefulWidget {
  const GuidancePage({super.key});

  @override
  State<GuidancePage> createState() => _GuidancePageState();
}

class _GuidancePageState extends State<GuidancePage> {
  final ImagePicker _picker = ImagePicker();

  /// Photo taken for each request, keyed by request id.
  final Map<String, String> _capturedByRequest = {};

  /// Ids of requests the user explicitly declined (e.g. a sealed game
  /// they don't want to open for the disc photo). Mutually exclusive
  /// with _capturedByRequest - doing one clears the other for that id.
  final Set<String> _skippedIds = {};

  bool _busy = false;

  /// How many of the requests have been dealt with one way or another -
  /// this, not a full checklist, is what unlocks "Reanalizar".
  int get _resolvedCount => _capturedByRequest.length + _skippedIds.length;

  Future<void> _capture(PhotoRequest request) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );

      if (!mounted) return;
      setState(() {
        if (photo != null) {
          _capturedByRequest[request.id] = photo.path;
          _skippedIds.remove(request.id);
        }
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la camara: $error')),
      );
    }
  }

  /// Toggles skipping this request - e.g. "no voy a abrir el juego
  /// sellado para fotografiar el disco". Taking a photo later un-skips
  /// it automatically (see _capture).
  void _toggleSkip(PhotoRequest request) {
    setState(() {
      if (_skippedIds.contains(request.id)) {
        _skippedIds.remove(request.id);
      } else {
        _skippedIds.add(request.id);
        _capturedByRequest.remove(request.id);
      }
    });
  }

  /// Send everything back for another identification pass - new photos,
  /// plus which requests got explicitly skipped this round.
  void _reanalyze(ScanSession session, RecognitionResult result) {
    final List<String> skippedTitles = result.requestedPhotos
        .where((request) => _skippedIds.contains(request.id))
        .map((request) => request.title)
        .toList();

    Navigator.pushReplacementNamed(
      context,
      'identifying',
      arguments: {
        'session': session.nextRound(
          newImagePaths: _capturedByRequest.values.toList(),
          result: result,
          newSkipped: skippedTitles,
        ),
      },
    );
  }

  /// Keep what we already know and go straight to pricing + saving.
  void _keepAsIs(ScanSession session, RecognitionResult result) {
    Navigator.pushReplacementNamed(
      context,
      'identifying',
      arguments: {'session': session, 'skipRecognitionWith': result},
    );
  }

  @override
  Widget build(BuildContext context) {
    final _GuidanceArgs? args = _resolveArgs(context);
    if (args == null) return const MissingProductScaffold();

    final RecognitionResult result = args.result;
    final ScanSession session = args.session;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Falta un poco mas'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: result.confidence,
            minHeight: 4,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _partialResult(context, result, session),
          const SizedBox(height: 24),
          Text(
            result.requestedPhotos.length == 1
                ? 'La IA necesita 1 foto mas'
                : 'La IA necesita ${result.requestedPhotos.length} fotos mas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Son especificas para este producto: resuelven lo que todavia '
            'no se puede ver.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ...result.requestedPhotos.map(
            (request) => _requestCard(context, request, session),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(context, session, result),
    );
  }

  /// What the model could already work out, and what it couldn't.
  Widget _partialResult(
    BuildContext context,
    RecognitionResult result,
    ScanSession session,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esto es lo que reconocio',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(session.primaryImagePath),
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      if (result.platform.isNotEmpty) Text(result.platform),
                      const SizedBox(height: 8),
                      Text('Certeza: ${percent(result.confidence)}'),
                    ],
                  ),
                ),
              ],
            ),
            if (result.missingInfo.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Todavia falta determinar:',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: result.missingInfo
                    .map(
                      (field) => Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(_missingLabel(field)),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// True when this exact request (same id, or same title) was already
  /// asked for in the previous round - meaning the photo taken back then
  /// didn't resolve it, and Gemini is asking again.
  bool _wasRepeated(ScanSession session, PhotoRequest request) {
    final RecognitionResult? previous = session.previousResult;
    if (previous == null) return false;

    return previous.requestedPhotos.any(
      (prev) =>
          prev.id == request.id ||
          prev.title.trim().toLowerCase() == request.title.trim().toLowerCase(),
    );
  }

  Widget _requestCard(
    BuildContext context,
    PhotoRequest request,
    ScanSession session,
  ) {
    final String? capturedPath = _capturedByRequest[request.id];
    final bool done = capturedPath != null;
    final bool skipped = _skippedIds.contains(request.id);
    final bool repeated = _wasRepeated(session, request);
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: repeated ? colors.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (repeated)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: colors.onErrorContainer,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'La foto anterior no alcanzo para ver esto. '
                        'Proba de nuevo con mejor luz y mas cerca.',
                        style: TextStyle(
                          color: colors.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Opacity(
              opacity: skipped ? 0.6 : 1,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (done)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(capturedPath),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Icon(
                      skipped ? Icons.block : Icons.photo_camera_outlined,
                      size: 32,
                      color: repeated ? colors.onErrorContainer : null,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: repeated
                                    ? colors.onErrorContainer
                                    : null,
                                decoration: skipped
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          skipped ? 'Omitido' : request.instruction,
                          style: TextStyle(
                            color: repeated ? colors.onErrorContainer : null,
                            fontStyle: skipped
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                        if (!skipped && request.reason.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            request.reason,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: repeated
                                      ? colors.onErrorContainer
                                      : null,
                                ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: skipped
                              ? TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _toggleSkip(request),
                                  icon: const Icon(Icons.undo, size: 18),
                                  label: const Text('Deshacer'),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _toggleSkip(request),
                                      child: const Text('Omitir'),
                                    ),
                                    const SizedBox(width: 4),
                                    done
                                        ? TextButton.icon(
                                            onPressed: _busy
                                                ? null
                                                : () => _capture(request),
                                            icon: const Icon(
                                              Icons.refresh,
                                              size: 18,
                                            ),
                                            label: const Text('Repetir'),
                                          )
                                        : FilledButton.icon(
                                            onPressed: _busy
                                                ? null
                                                : () => _capture(request),
                                            icon: const Icon(
                                              Icons.photo_camera,
                                              size: 18,
                                            ),
                                            label: const Text('Sacar foto'),
                                          ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(
    BuildContext context,
    ScanSession session,
    RecognitionResult result,
  ) {
    final int total = result.requestedPhotos.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_resolvedCount de $total resueltas  -  intento '
              '${session.round} de ${ScanSession.maxRounds}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                // One new photo (or one explicit skip) is enough to be
                // worth another pass; the user shouldn't be forced to
                // resolve every single request.
                onPressed: (_resolvedCount == 0 || _busy)
                    ? null
                    : () => _reanalyze(session, result),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Reanalizar'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _busy ? null : () => _keepAsIs(session, result),
              child: const Text('Guardar asi, sin mas fotos'),
            ),
          ],
        ),
      ),
    );
  }

  String _missingLabel(String field) {
    switch (field) {
      case 'title':
        return 'Titulo';
      case 'platform':
        return 'Plataforma';
      case 'region':
        return 'Region';
      case 'model_code':
        return 'Codigo de catalogo';
      case 'edition':
        return 'Edicion';
      case 'completeness':
        return 'Que incluye';
      case 'condition':
        return 'Estado';
      default:
        return field;
    }
  }
}

/// Route arguments for this screen.
class _GuidanceArgs {
  const _GuidanceArgs({required this.session, required this.result});
  final ScanSession session;
  final RecognitionResult result;
}

_GuidanceArgs? _resolveArgs(BuildContext context) {
  final Object? arguments = ModalRoute.of(context)?.settings.arguments;

  if (arguments is Map) {
    final Object? session = arguments['session'];
    final Object? result = arguments['result'];
    if (session is ScanSession && result is RecognitionResult) {
      return _GuidanceArgs(session: session, result: result);
    }
  }

  // Shouldn't happen in the real flow (this screen is only ever
  // reached from identifying_page), but better a fallback screen than
  // an exception thrown mid-build.
  return null;
}
