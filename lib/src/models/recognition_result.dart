/// What Gemini sends back for one identification pass.
/// Mirrors the JSON schema declared in gemini_service.dart - if you change
/// one, change the other.
class RecognitionResult {
  const RecognitionResult({
    required this.isSupported,
    required this.rejectionReason,
    required this.itemType,
    required this.title,
    required this.brand,
    required this.platform,
    required this.region,
    required this.modelCode,
    required this.edition,
    required this.completeness,
    required this.conditionNotes,
    required this.confidence,
    required this.identificationComplete,
    required this.missingInfo,
    required this.requestedPhotos,
    required this.ebayQuery,
    required this.listingTitle,
    required this.listingDescription,
    this.estimatedPriceMin = 0,
    this.estimatedPriceMax = 0,
  });

  /// False when the photo isn't a physical game / console / accessory.
  /// Everything else is meaningless when this is false.
  final bool isSupported;

  /// Spanish explanation of what was seen instead, when unsupported.
  final String rejectionReason;

  /// 'game' | 'console' | 'accessory' | 'unknown'
  final String itemType;

  final String title;
  final String brand;

  /// e.g. "PlayStation 2". Empty when it couldn't be determined.
  final String platform;

  /// 'NTSC-U' | 'NTSC-J' | 'PAL' | 'unknown'
  final String region;

  /// Catalog/serial code: SLUS-20228 for a game, SCPH-39001 for a console.
  final String modelCode;

  /// "Greatest Hits", "Platinum", "Collector's Edition"... empty if plain.
  final String edition;

  /// 'complete_in_box' | 'game_only' | 'console_only' | ...
  final String completeness;

  final String conditionNotes;

  /// 0.0 - 1.0.
  final double confidence;

  /// The model's own call on whether it has everything it needs.
  final bool identificationComplete;

  /// Which fields it still couldn't pin down.
  final List<String> missingInfo;

  /// Extra photos it wants in order to finish the job. This is what
  /// drives the guidance screen - see PhotoRequest.
  final List<PhotoRequest> requestedPhotos;

  /// English search string to run against eBay.
  final String ebayQuery;

  final String listingTitle;
  final String listingDescription;

  /// Gemini's own rough estimate of resale value in USD, used as a
  /// fallback reference price when eBay/MercadoLibre both come up empty.
  /// Not from a real listing - just the model's general knowledge,
  /// adjusted for the item's visible condition.
  final double estimatedPriceMin;
  final double estimatedPriceMax;

  /// Good enough to stop asking for photos and save it.
  bool get isConclusive =>
      isSupported && identificationComplete && confidence >= 0.80;

  /// True when the app should send the user to the guidance screen.
  bool get needsMorePhotos =>
      isSupported && !isConclusive && requestedPhotos.isNotEmpty;

  bool get isConsole => itemType == 'console';

  /// Display name that always says something useful.
  String get displayName => title.trim().isEmpty
      ? (platform.trim().isEmpty ? 'Producto sin identificar' : platform)
      : title;

  factory RecognitionResult.fromJson(Map<String, dynamic> json) {
    return RecognitionResult(
      isSupported: json['is_supported'] as bool? ?? false,
      rejectionReason: _str(json['rejection_reason']),
      itemType: _str(json['item_type'], fallback: 'unknown'),
      title: _str(json['title']),
      brand: _str(json['brand']),
      platform: _str(json['platform']),
      region: _str(json['region'], fallback: 'unknown'),
      modelCode: _str(json['model_code']),
      edition: _str(json['edition']),
      completeness: _str(json['completeness'], fallback: 'unknown'),
      conditionNotes: _str(json['condition_notes']),
      confidence: _toDouble(json['confidence']),
      identificationComplete: json['identification_complete'] as bool? ?? false,
      missingInfo: _stringList(json['missing_info']),
      requestedPhotos: _photoRequests(json['requested_photos']),
      ebayQuery: _str(json['ebay_query']),
      listingTitle: _str((json['listing'] as Map?)?['title']),
      listingDescription: _str((json['listing'] as Map?)?['description']),
      estimatedPriceMin: _toPrice(json['estimated_price_min_usd']),
      estimatedPriceMax: _toPrice(json['estimated_price_max_usd']),
    );
  }

  static double _toPrice(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _str(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    final String text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return text;
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble().clamp(0.0, 1.0);
    return double.tryParse(value?.toString() ?? '')?.clamp(0.0, 1.0) ?? 0.0;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }

  static List<PhotoRequest> _photoRequests(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => PhotoRequest.fromJson(item.cast<String, dynamic>()))
        .where((request) => request.title.isNotEmpty)
        .toList();
  }
}

/// One concrete extra photo the model asked for, e.g. "the back of the
/// case, so I can read the catalog code".
class PhotoRequest {
  const PhotoRequest({
    required this.id,
    required this.title,
    required this.instruction,
    required this.reason,
  });

  final String id;
  final String title;
  final String instruction;
  final String reason;

  factory PhotoRequest.fromJson(Map<String, dynamic> json) {
    return PhotoRequest(
      id: RecognitionResult._str(json['id'], fallback: 'photo'),
      title: RecognitionResult._str(json['title']),
      instruction: RecognitionResult._str(json['instruction']),
      reason: RecognitionResult._str(json['reason']),
    );
  }
}
