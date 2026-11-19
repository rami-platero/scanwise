import '../models/recognition_result.dart';
import '../models/scan_session.dart';
import 'fake_catalog.dart' as catalog;

/// Offline stand-in for Gemini, used when `useMockRecognition` is true in
/// api_config.dart. It produces the same RecognitionResult the real
/// service does, so every screen downstream behaves identically - handy
/// as a fallback when the venue wifi or the API is having a bad day.
Future<RecognitionResult> mockIdentify(ScanSession session) async {
  // A touch of delay so the progress UI doesn't flash past.
  await Future<void>.delayed(const Duration(milliseconds: 900));

  final catalog.ScanScenario scenario = catalog.randomScenario();

  // Second pass: pretend the extra photos resolved everything.
  final bool finished = session.round > 1 || scenario.guidanceSteps.isEmpty;

  return RecognitionResult(
    isSupported: true,
    rejectionReason: '',
    itemType: scenario.category == 'Consolas' ? 'console' : 'game',
    title: finished ? scenario.confirmedName : scenario.guessName,
    brand: scenario.brand,
    platform: scenario.category == 'Consolas'
        ? scenario.brand
        : 'PlayStation 2',
    region: 'NTSC-U',
    modelCode: finished ? scenario.confirmedModel : '',
    edition: '',
    completeness: 'unknown',
    conditionNotes: 'Estado estimado en modo demo.',
    confidence: finished
        ? scenario.confirmedConfidence
        : scenario.guessConfidence,
    identificationComplete: finished,
    missingInfo: finished ? const [] : const ['model_code', 'region'],
    requestedPhotos: finished
        ? const []
        : scenario.guidanceSteps
              .map(
                (step) => PhotoRequest(
                  id: step['title'] ?? 'foto',
                  title: step['title'] ?? '',
                  instruction: step['hint'] ?? '',
                  reason: 'Necesario para confirmar la version exacta.',
                ),
              )
              .toList(),
    ebayQuery: finished
        ? '${scenario.confirmedName} ${scenario.confirmedModel}'
        : scenario.guessName,
    listingTitle: finished ? scenario.confirmedName : scenario.guessName,
    listingDescription: scenario.description,
    // Mirrors the scenario's own sample range, same as the real model
    // would estimate before a live search confirms it.
    estimatedPriceMin: scenario.priceMin,
    estimatedPriceMax: scenario.priceMax,
  );
}
