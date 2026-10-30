import '../models/product.dart';

/// Datos de prueba. Mas adelante esto se reemplaza por la respuesta
/// del servicio de identificacion y por la base de datos local.
class _ProductProvider {
  /// Resultado del primer escaneo: la IA reconoce la categoria y la marca,
  /// pero no la version exacta (certeza baja a proposito, asi se puede
  /// probar el flujo de guia interactiva).
  Product firstGuess() {
    return const Product(
      name: 'Auriculares inalambricos',
      brand: 'Sony',
      category: 'Audio',
      model: '',
      confidence: 0.62,
      priceMin: 120,
      priceMax: 210,
      scannedAt: 'Hoy, 14:32',
      icon: 'headphones',
      description:
          'Auriculares inalambricos con cancelacion de ruido. La version '
          'exacta no pudo determinarse con la primera foto.',
    );
  }

  /// Fotos adicionales que la app pide cuando la certeza es baja.
  List<Map<String, String>> guidanceSteps() {
    return <Map<String, String>>[
      {
        'title': 'Foto del logo',
        'hint': 'Acerca la camara al logo de la marca, sin reflejos.',
        'icon': 'camera',
      },
      {
        'title': 'Panel trasero',
        'hint': 'Captura la parte de atras completa del producto.',
        'icon': 'devices_other',
      },
      {
        'title': 'Numero de serie',
        'hint': 'Suele estar en una etiqueta pequena, debajo del producto.',
        'icon': 'smartphone',
      },
    ];
  }

  /// Publicaciones parecidas que se usan para el rango de precio.
  List<Map<String, dynamic>> similarListings() {
    return <Map<String, dynamic>>[
      {
        'title': 'Sony WH-1000XM4 usados',
        'platform': 'MercadoLibre',
        'condition': 'Usado - Muy bueno',
        'price': 185.0,
      },
      {
        'title': 'Auriculares Sony XM4 con estuche',
        'platform': 'Facebook Marketplace',
        'condition': 'Usado - Bueno',
        'price': 160.0,
      },
      {
        'title': 'Sony WH-1000XM4 caja abierta',
        'platform': 'eBay',
        'condition': 'Reacondicionado',
        'price': 205.0,
      },
      {
        'title': 'Sony WH-1000XM4 sin accesorios',
        'platform': 'OLX',
        'condition': 'Usado - Aceptable',
        'price': 132.0,
      },
    ];
  }

  /// Historial de productos ya identificados.
  List<Product> history() {
    return <Product>[
      const Product(
        name: 'Sony WH-1000XM4',
        brand: 'Sony',
        category: 'Audio',
        model: 'WH-1000XM4',
        confidence: 0.97,
        priceMin: 130,
        priceMax: 205,
        scannedAt: 'Hoy, 14:32',
        icon: 'headphones',
      ),
      const Product(
        name: 'iPhone 13 128GB',
        brand: 'Apple',
        category: 'Telefonos',
        model: 'A2633',
        confidence: 0.94,
        priceMin: 380,
        priceMax: 470,
        scannedAt: 'Ayer, 19:05',
        icon: 'smartphone',
      ),
      const Product(
        name: 'Nintendo Switch OLED',
        brand: 'Nintendo',
        category: 'Consolas',
        model: 'HEG-001',
        confidence: 0.91,
        priceMin: 250,
        priceMax: 310,
        scannedAt: '28/10/2026',
        icon: 'videogame',
      ),
      const Product(
        name: 'Reloj deportivo',
        brand: 'Garmin',
        category: 'Wearables',
        model: '',
        confidence: 0.58,
        priceMin: 90,
        priceMax: 180,
        scannedAt: '26/10/2026',
        icon: 'watch',
      ),
    ];
  }

  /// Avisos de identificacion lista y de cambios de precio.
  List<Map<String, dynamic>> notifications() {
    return <Map<String, dynamic>>[
      {
        'title': 'Identificacion completada',
        'body': 'Sony WH-1000XM4 fue identificado con 97% de certeza.',
        'time': 'Hace 5 min',
        'icon': 'headphones',
        'unread': true,
      },
      {
        'title': 'El precio bajo',
        'body': 'iPhone 13 128GB ahora promedia \$425 (antes \$440).',
        'time': 'Hace 2 h',
        'icon': 'smartphone',
        'unread': true,
      },
      {
        'title': 'Identificacion incompleta',
        'body': 'Falta la foto del numero de serie del reloj Garmin.',
        'time': 'Ayer',
        'icon': 'watch',
        'unread': false,
      },
      {
        'title': 'El precio subio',
        'body': 'Nintendo Switch OLED ahora promedia \$290 (antes \$275).',
        'time': '28/10/2026',
        'icon': 'videogame',
        'unread': false,
      },
    ];
  }
}

/// Instancia unica para usar desde las paginas, igual que menuProvider.
final productProvider = _ProductProvider();
