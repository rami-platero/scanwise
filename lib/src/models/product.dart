import '../utils/format_util.dart';
import 'market_listing.dart';
import 'recognition_result.dart';

/// A physical game, console or console accessory the user scanned.
class Product {
  const Product({
    this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.model,
    required this.confidence,
    required this.priceMin,
    required this.priceMax,
    required this.scannedAt,
    this.icon = 'videogame',
    this.description = '',
    this.itemType = 'game',
    this.platform = '',
    this.region = '',
    this.edition = '',
    this.completeness = '',
    this.ebayQuery = '',
    this.priceSource = '',
    this.photoPath,
    this.barcodeValue,
    this.scenarioId,
    this.catalogImageAsset,
  });

  /// Id of the row in Supabase. Null until it's been saved.
  final String? id;

  final String name;
  final String brand;

  /// User-facing bucket: "Juegos", "Consolas" or "Accesorios".
  final String category;

  /// Catalog/serial code (SLUS-20228, SCPH-39001). Often empty - plenty
  /// of items don't show one in the photo.
  final String model;

  /// Identification confidence, 0.0 - 1.0.
  final double confidence;

  final double priceMin;
  final double priceMax;
  final String scannedAt;
  final String icon;
  final String description;

  /// 'game' | 'console' | 'accessory' | 'unknown'.
  final String itemType;

  /// e.g. "PlayStation 2".
  final String platform;

  /// 'NTSC-U' | 'NTSC-J' | 'PAL' | 'unknown' (or empty).
  final String region;

  /// "Greatest Hits", "Platinum"... empty for a standard release.
  final String edition;

  /// How complete the item is, as judged from the photos.
  final String completeness;

  /// The English search string used against eBay, kept so the price
  /// screen can re-run the same search without guessing it again.
  final String ebayQuery;

  /// Where priceMin/priceMax came from: 'eBay', 'MercadoLibre', or
  /// 'IA (estimado)' when neither marketplace had an answer and this is
  /// just Gemini's own best guess. Empty for old rows saved before this
  /// field existed.
  final String priceSource;

  /// Local path of the real photo. Copied into permanent app storage on
  /// save, and referenced from the database through image_ref.
  final String? photoPath;

  /// Barcode, when the scan started from the barcode scanner.
  final String? barcodeValue;

  /// Which bundled sample this came from, when running in mock mode.
  final String? scenarioId;

  /// Bundled cover image, only used by the mock catalog.
  final String? catalogImageAsset;

  /// Whether the identification is solid enough to treat as final.
  /// Based on confidence alone: a missing catalog code is normal (lots
  /// of releases don't show one), so it shouldn't mark an item pending.
  bool get isExactModel => confidence >= 0.80;

  bool get isConsole => itemType == 'console';

  double get suggestedPrice => (priceMin + priceMax) / 2;

  /// Short line under the product name, e.g. "PlayStation 2 - NTSC-U".
  String get subtitle {
    final List<String> parts = [
      if (platform.isNotEmpty) platform,
      if (region.isNotEmpty && region != 'unknown') region,
      if (edition.isNotEmpty) edition,
    ];
    return parts.isEmpty ? category : parts.join(' - ');
  }

  /// Encodes the picture into the single "image_ref" column:
  /// `asset:<path>` for a bundled image, `file:<path>` for a real photo.
  String? get imageRef {
    if (catalogImageAsset != null) return 'asset:$catalogImageAsset';
    if (photoPath != null) return 'file:$photoPath';
    return null;
  }

  /// Builds a product out of one Gemini identification, priced with
  /// whatever answered first: a real marketplace if [prices] has
  /// listings, otherwise Gemini's own estimate as a fallback.
  factory Product.fromRecognition(
    RecognitionResult result, {
    MarketPriceReport? prices,
    String? photoPath,
    String? barcodeValue,
  }) {
    final bool hasRealPrices = prices != null && !prices.isEmpty;

    return Product(
      name: result.displayName,
      brand: result.brand,
      category: _categoryFor(result.itemType),
      model: result.modelCode,
      confidence: result.confidence,
      priceMin: hasRealPrices ? prices.minPrice : result.estimatedPriceMin,
      priceMax: hasRealPrices ? prices.maxPrice : result.estimatedPriceMax,
      scannedAt: 'Ahora',
      icon: _iconFor(result.itemType),
      description: result.listingDescription.isEmpty
          ? result.conditionNotes
          : result.listingDescription,
      itemType: result.itemType,
      platform: result.platform,
      region: result.region == 'unknown' ? '' : result.region,
      edition: result.edition,
      completeness: result.completeness,
      ebayQuery: result.ebayQuery,
      priceSource: hasRealPrices ? prices.source : 'IA (estimado)',
      photoPath: photoPath,
      barcodeValue: barcodeValue,
    );
  }

  static String _categoryFor(String itemType) {
    switch (itemType) {
      case 'console':
        return 'Consolas';
      case 'accessory':
        return 'Accesorios';
      case 'game':
        return 'Juegos';
      default:
        return 'Sin categoria';
    }
  }

  static String _iconFor(String itemType) {
    switch (itemType) {
      case 'console':
        return 'videogame';
      case 'accessory':
        return 'devices_other';
      default:
        return 'videogame';
    }
  }

  /// Returns a copy changing only the given fields.
  Product copyWith({
    String? id,
    String? name,
    String? model,
    double? confidence,
    double? priceMin,
    double? priceMax,
    String? description,
    String? ebayQuery,
    String? priceSource,
    String? photoPath,
    String? barcodeValue,
    String? scenarioId,
    String? catalogImageAsset,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand,
      category: category,
      model: model ?? this.model,
      confidence: confidence ?? this.confidence,
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      scannedAt: scannedAt,
      icon: icon,
      description: description ?? this.description,
      itemType: itemType,
      platform: platform,
      region: region,
      edition: edition,
      completeness: completeness,
      ebayQuery: ebayQuery ?? this.ebayQuery,
      priceSource: priceSource ?? this.priceSource,
      photoPath: photoPath ?? this.photoPath,
      barcodeValue: barcodeValue ?? this.barcodeValue,
      scenarioId: scenarioId ?? this.scenarioId,
      catalogImageAsset: catalogImageAsset ?? this.catalogImageAsset,
    );
  }

  /// Builds a Product from a row of the "products" table, decoding
  /// "image_ref" back into catalogImageAsset or photoPath.
  factory Product.fromMap(Map<String, dynamic> map) {
    final String? imageRef = map['image_ref'] as String?;
    String? catalogImageAsset;
    String? photoPath;

    if (imageRef != null) {
      if (imageRef.startsWith('asset:')) {
        catalogImageAsset = imageRef.substring('asset:'.length);
      } else if (imageRef.startsWith('file:')) {
        photoPath = imageRef.substring('file:'.length);
      }
    }

    return Product(
      id: map['id'] as String?,
      name: map['name'] as String,
      brand: map['brand'] as String,
      category: map['category'] as String,
      model: (map['model'] as String?) ?? '',
      confidence: (map['confidence'] as num).toDouble(),
      priceMin: (map['price_min'] as num).toDouble(),
      priceMax: (map['price_max'] as num).toDouble(),
      scannedAt: formatScannedAt(DateTime.parse(map['scanned_at'] as String)),
      icon: (map['icon'] as String?) ?? 'videogame',
      description: (map['description'] as String?) ?? '',
      itemType: (map['item_type'] as String?) ?? 'game',
      platform: (map['platform'] as String?) ?? '',
      region: (map['region'] as String?) ?? '',
      edition: (map['edition'] as String?) ?? '',
      completeness: (map['completeness'] as String?) ?? '',
      ebayQuery: (map['ebay_query'] as String?) ?? '',
      priceSource: (map['price_source'] as String?) ?? '',
      catalogImageAsset: catalogImageAsset,
      photoPath: photoPath,
    );
  }

  /// Fields sent on insert. "scanned_at" is left out on purpose (the
  /// database defaults it), and "user_id" is added by ProductService.
  Map<String, dynamic> toInsertMap() {
    return <String, dynamic>{
      'name': name,
      'brand': brand,
      'category': category,
      'model': model,
      'confidence': confidence,
      'price_min': priceMin,
      'price_max': priceMax,
      'icon': icon,
      'description': description,
      'item_type': itemType,
      'platform': platform,
      'region': region,
      'edition': edition,
      'completeness': completeness,
      'ebay_query': ebayQuery,
      'price_source': priceSource,
      'image_ref': imageRef,
    };
  }
}
