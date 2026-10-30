import 'package:flutter/material.dart';

/// Mapa de nombres de icono a iconos de Material.
/// Permite guardar el icono como texto dentro de los datos del producto.
final Map<String, IconData> _icons = <String, IconData>{
  'devices_other': Icons.devices_other,
  'headphones': Icons.headphones,
  'smartphone': Icons.smartphone,
  'laptop': Icons.laptop_mac,
  'watch': Icons.watch,
  'camera': Icons.photo_camera,
  'videogame': Icons.videogame_asset,
  'speaker': Icons.speaker,
};

Icon getIcon(String name, {double size = 24, Color? color}) {
  return Icon(
    _icons[name] ?? Icons.devices_other,
    size: size,
    color: color,
  );
}
