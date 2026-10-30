/// Modelo simple de un producto identificado por la app.
class Product {
  const Product({
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
  });

  final String name;
  final String brand;
  final String category;

  /// Version exacta del producto. Vacio si todavia no se pudo determinar.
  final String model;

  /// Nivel de certeza de la identificacion, de 0.0 a 1.0.
  final double confidence;

  final double priceMin;
  final double priceMax;
  final String scannedAt;
  final String icon;
  final String description;

  /// Cuando la certeza es alta no hace falta pedir mas fotos.
  bool get isExactModel => confidence >= 0.85 && model.isNotEmpty;

  double get suggestedPrice => (priceMin + priceMax) / 2;

  /// Devuelve una copia cambiando solo los campos indicados.
  Product copyWith({
    String? name,
    String? model,
    double? confidence,
    double? priceMin,
    double? priceMax,
    String? description,
  }) {
    return Product(
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
    );
  }
}
