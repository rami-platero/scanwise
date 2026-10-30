/// Formatea un monto para mostrarlo en pantalla.
String money(num value) => '\$${value.toStringAsFixed(0)}';

/// Convierte la certeza (0.0 - 1.0) en un porcentaje legible.
String percent(double value) => '${(value * 100).toStringAsFixed(0)}%';
