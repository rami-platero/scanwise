import 'recognition_result.dart';

/// Carries one identification attempt across screens.
///
/// The "ask for more photos" loop works like this:
///   1. Camera takes a photo -> session with 1 image, round 1.
///   2. Gemini looks at it. If it can't finish, it returns concrete
///      photo requests (back of the case, serial sticker, ...).
///   3. The guidance screen collects those photos, appending each one
///      to [imagePaths] - or the user explicitly skips one (e.g. a
///      sealed game they don't want to open), which goes to
///      [skippedRequests] instead.
///   4. Gemini is called again with ALL the images at once, round 2,
///      told which requests were skipped so it stops re-asking for
///      them. It either finishes, or asks for a bit more (up to
///      [maxRounds]).
///
/// Everything here is in memory only - it exists for the duration of one
/// scan and is thrown away once the product is saved.
class ScanSession {
  ScanSession({
    required this.imagePaths,
    this.barcode,
    this.round = 1,
    this.previousResult,
    this.skippedRequests = const [],
  });

  /// Every photo taken so far for this item, oldest first. All of them
  /// get sent on each pass, so the model sees the full picture.
  final List<String> imagePaths;

  /// Barcode, when the scan started from the barcode screen.
  final String? barcode;

  /// Which identification pass we're on (1-based).
  final int round;

  /// What the previous pass concluded, so the next prompt can say
  /// "you asked for X, here it is - refine this".
  final RecognitionResult? previousResult;

  /// Short descriptions of photo requests the user explicitly declined
  /// to provide (e.g. "Foto del disco" for a sealed game), carried
  /// across every round so Gemini stops asking for them again.
  final List<String> skippedRequests;

  /// Hard stop so a stubborn item can't loop forever asking for photos.
  static const int maxRounds = 3;

  bool get isFinalRound => round >= maxRounds;

  String get primaryImagePath => imagePaths.first;

  /// Next pass: same item, more photos (and/or more skips), round bumped.
  ScanSession nextRound({
    required List<String> newImagePaths,
    required RecognitionResult result,
    List<String> newSkipped = const [],
  }) {
    return ScanSession(
      imagePaths: [...imagePaths, ...newImagePaths],
      barcode: barcode,
      round: round + 1,
      previousResult: result,
      skippedRequests: [...skippedRequests, ...newSkipped],
    );
  }
}
