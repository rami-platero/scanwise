import '../utils/format_util.dart';

/// Simple data class for a product identified by the app.
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
    this.icon = 'devices_other',
    this.description = '',
    this.photoPath,
    this.barcodeValue,
    this.scenarioId,
    this.catalogImageAsset,
  });

  /// Id of the row in Supabase. Null for products that haven't been
  /// saved yet (for example, while identification is still in progress).
  final String? id;

  final String name;
  final String brand;
  final String category;

  /// Exact product version. Empty if it couldn't be determined yet.
  final String model;

  /// Identification confidence, from 0.0 to 1.0.
  final double confidence;

  final double priceMin;
  final double priceMax;
  final String scannedAt;
  final String icon;
  final String description;

  /// Local path of the real photo taken with the camera (image_picker).
  /// Not stored in Supabase - no Storage bucket set up yet, so this only
  /// lives for as long as the app keeps this Product in memory/navigation.
  final String? photoPath;

  /// Code read by the real barcode scanner (mobile_scanner), if this
  /// product came from that flow. Also local-only, not persisted.
  final String? barcodeValue;

  /// Which sample catalog entry (see fake_catalog.dart) this guess came
  /// from. Lets guidance_page look up the matching "confirmed" data for
  /// the same item. Local-only, not persisted.
  final String? scenarioId;

  /// Asset path of a curated cover image for this catalog entry (see
  /// fake_catalog.dart), used when one exists - e.g. real game cover art
  /// for the two Silent Hill samples. When null, the real photo
  /// (photoPath) is shown instead. Local-only, not persisted.
  final String? catalogImageAsset;

  /// When confidence is high there's no need to ask for more photos.
  bool get isExactModel => confidence >= 0.85 && model.isNotEmpty;

  double get suggestedPrice => (priceMin + priceMax) / 2;

  /// Encodes whichever picture this product has into the single
  /// "image_ref" column: `asset:<path>` for a curated cover, or
  /// `file:<path>` for a real photo (already copied into permanent
  /// storage by the time this is saved - see ProductService.create).
  /// Null when there's no picture at all.
  String? get imageRef {
    if (catalogImageAsset != null) return 'asset:$catalogImageAsset';
    if (photoPath != null) return 'file:$photoPath';
    return null;
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
      icon: (map['icon'] as String?) ?? 'devices_other',
      description: (map['description'] as String?) ?? '',
      catalogImageAsset: catalogImageAsset,
      photoPath: photoPath,
    );
  }

  /// Fields sent on insert. "scanned_at" is left out on purpose: the
  /// database fills it in with the current date/time by default.
  /// barcodeValue/scenarioId are local-only and never sent to Supabase;
  /// the picture goes through "image_ref" (see imageRef above) instead
  /// of being split across two columns.
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
      'image_ref': imageRef,
    };
  }
}
