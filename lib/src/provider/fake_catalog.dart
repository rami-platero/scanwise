import 'dart:math';

import '../models/product.dart';

/// One sample "scan result" the mocked identification can land on.
/// Stands in for what a real recognition model would eventually return:
/// a rough first guess (brand/category known, exact model not yet) and
/// what it looks like once confirmed through the guidance flow.
class ScanScenario {
  const ScanScenario({
    required this.id,
    required this.guessName,
    required this.brand,
    required this.category,
    required this.guessConfidence,
    required this.confirmedName,
    required this.confirmedModel,
    required this.confirmedConfidence,
    required this.priceMin,
    required this.priceMax,
    required this.description,
    required this.icon,
    required this.listings,
    this.coverImageAsset,
    this.guidanceSteps = const [],
  });

  final String id;
  final String guessName;
  final String brand;
  final String category;
  final double guessConfidence;
  final String confirmedName;
  final String confirmedModel;
  final double confirmedConfidence;
  final double priceMin;
  final double priceMax;
  final String description;
  final String icon;
  final List<Map<String, dynamic>> listings;

  /// Curated cover image for this item, if one exists (real game cover
  /// art for the Silent Hill samples). Null for the console samples -
  /// those show the user's own captured photo instead.
  final String? coverImageAsset;

  /// Extra photos the guidance screen asks for before confirming this
  /// item. Can be empty: not every product needs extra depth - a clear
  /// cover shot can already be enough on its own, same as a real
  /// recognition model would decide dynamically per item.
  final List<Map<String, String>> guidanceSteps;
}

const List<ScanScenario> _scenarios = [
  ScanScenario(
    id: 'silent_hill_2',
    guessName: 'Juego de PlayStation 2',
    brand: 'Konami',
    category: 'Videojuegos',
    guessConfidence: 0.58,
    confirmedName: 'Silent Hill 2',
    confirmedModel: 'SLUS-20228',
    confirmedConfidence: 0.95,
    priceMin: 45,
    priceMax: 90,
    description:
        'Juego de PlayStation 2, edicion NTSC-U (SLUS-20228). Terror '
        'psicologico, uno de los mas buscados de la saga.',
    icon: 'videogame',
    coverImageAsset: 'assets/covers/silent_hill_2.jpg',
    // The cover art alone is enough to confirm this one - no extra
    // photos needed.
    guidanceSteps: [],
    // Every listing below is explicitly the same confirmed model
    // (SLUS-20228) - no mixing in other regions/editions, which is
    // what made these comparisons feel arbitrary before.
    listings: [
      {
        'title': 'Silent Hill 2 (SLUS-20228) usado',
        'platform': 'MercadoLibre',
        'condition': 'Usado - Bueno',
        'price': 75.0,
      },
      {
        'title': 'Silent Hill 2 (SLUS-20228) completo con manual',
        'platform': 'eBay',
        'condition': 'Usado - Muy bueno',
        'price': 95.0,
      },
      {
        'title': 'Silent Hill 2 (SLUS-20228) solo disco',
        'platform': 'Facebook Marketplace',
        'condition': 'Usado - Aceptable',
        'price': 40.0,
      },
    ],
  ),
  ScanScenario(
    id: 'silent_hill_3',
    guessName: 'Juego de PlayStation 2',
    brand: 'Konami',
    category: 'Videojuegos',
    guessConfidence: 0.52,
    confirmedName: 'Silent Hill 3',
    confirmedModel: 'SLUS-20550',
    confirmedConfidence: 0.93,
    priceMin: 60,
    priceMax: 130,
    description:
        'Juego de PlayStation 2 (SLUS-20550), secuela directa de Silent '
        'Hill 2. Muy buscado por coleccionistas.',
    icon: 'videogame',
    coverImageAsset: 'assets/covers/silent_hill_3.jpg',
    // This one has several regional re-releases, so one extra photo
    // confirms exactly which edition it is.
    guidanceSteps: [
      {
        'title': 'Foto de la contratapa',
        'hint': 'Para confirmar la edicion y la region exacta.',
        'icon': 'camera',
      },
    ],
    listings: [
      {
        'title': 'Silent Hill 3 (SLUS-20550) usado',
        'platform': 'MercadoLibre',
        'condition': 'Usado - Bueno',
        'price': 110.0,
      },
      {
        'title': 'Silent Hill 3 (SLUS-20550) caja y manual',
        'platform': 'eBay',
        'condition': 'Usado - Muy bueno',
        'price': 145.0,
      },
      {
        'title': 'Silent Hill 3 (SLUS-20550) solo disco, con rayones',
        'platform': 'OLX',
        'condition': 'Usado - Aceptable',
        'price': 65.0,
      },
    ],
  ),
  ScanScenario(
    id: 'ps2_fat',
    guessName: 'Consola de videojuegos',
    brand: 'Sony',
    category: 'Consolas',
    guessConfidence: 0.70,
    confirmedName: 'PlayStation 2 Fat',
    confirmedModel: 'SCPH-30000',
    confirmedConfidence: 0.92,
    priceMin: 80,
    priceMax: 160,
    description:
        'Consola PlayStation 2 modelo Fat (SCPH-30000), con lector de '
        'discos original.',
    icon: 'videogame',
    // No curated cover for hardware - shows the real captured photo.
    coverImageAsset: null,
    // Telling Fat from Slim, and confirming the exact revision, needs
    // the back panel and the serial sticker.
    guidanceSteps: [
      {
        'title': 'Panel trasero',
        'hint': 'Para confirmar que es el modelo Fat, no el Slim.',
        'icon': 'devices_other',
      },
      {
        'title': 'Numero de serie',
        'hint': 'Suele estar en una etiqueta en la base de la consola.',
        'icon': 'smartphone',
      },
    ],
    // Same model (SCPH-30000) in every listing - not a mix of Fat/Slim
    // revisions, which is what made this comparison ambiguous before.
    listings: [
      {
        'title': 'PlayStation 2 Fat (SCPH-30000) con 1 control',
        'platform': 'MercadoLibre',
        'condition': 'Usado - Bueno',
        'price': 130.0,
      },
      {
        'title': 'PlayStation 2 Fat (SCPH-30000) completa, caja original',
        'platform': 'eBay',
        'condition': 'Usado - Muy bueno',
        'price': 165.0,
      },
      {
        'title': 'PlayStation 2 Fat (SCPH-30000) sin cables',
        'platform': 'Facebook Marketplace',
        'condition': 'Usado - Aceptable',
        'price': 85.0,
      },
    ],
  ),
  ScanScenario(
    id: 'gamecube',
    guessName: 'Consola de videojuegos',
    brand: 'Nintendo',
    category: 'Consolas',
    guessConfidence: 0.65,
    confirmedName: 'Nintendo GameCube',
    confirmedModel: 'DOL-001',
    confirmedConfidence: 0.90,
    priceMin: 70,
    priceMax: 150,
    description:
        'Consola Nintendo GameCube (DOL-001), incluye lector de mini-DVD.',
    icon: 'videogame',
    coverImageAsset: null,
    // Just needs a clear look at the logo to confirm the color/region.
    guidanceSteps: [
      {
        'title': 'Foto del logo',
        'hint': 'Para confirmar el color y la region exacta.',
        'icon': 'camera',
      },
    ],
    listings: [
      {
        'title': 'Nintendo GameCube (DOL-001) con 1 control',
        'platform': 'MercadoLibre',
        'condition': 'Usado - Bueno',
        'price': 115.0,
      },
      {
        'title': 'Nintendo GameCube (DOL-001) completa',
        'platform': 'eBay',
        'condition': 'Usado - Muy bueno',
        'price': 150.0,
      },
      {
        'title': 'Nintendo GameCube (DOL-001) sin cables',
        'platform': 'OLX',
        'condition': 'Usado - Aceptable',
        'price': 75.0,
      },
    ],
  ),
  ScanScenario(
    id: 'xbox_original',
    guessName: 'Consola de videojuegos',
    brand: 'Microsoft',
    category: 'Consolas',
    guessConfidence: 0.60,
    confirmedName: 'Xbox Original',
    confirmedModel: 'Model 1',
    confirmedConfidence: 0.89,
    priceMin: 50,
    priceMax: 110,
    description: 'Consola Xbox original de Microsoft, primera generacion.',
    icon: 'videogame',
    coverImageAsset: null,
    guidanceSteps: [
      {
        'title': 'Panel trasero',
        'hint': 'Para confirmar las salidas de video y la revision.',
        'icon': 'devices_other',
      },
      {
        'title': 'Numero de serie',
        'hint': 'Esta en una etiqueta debajo de la consola.',
        'icon': 'smartphone',
      },
    ],
    listings: [
      {
        'title': 'Xbox Original (Model 1) con 1 control',
        'platform': 'MercadoLibre',
        'condition': 'Usado - Bueno',
        'price': 85.0,
      },
      {
        'title': 'Xbox Original (Model 1) completa, caja y cables',
        'platform': 'eBay',
        'condition': 'Usado - Muy bueno',
        'price': 110.0,
      },
      {
        'title': 'Xbox Original (Model 1) sin control',
        'platform': 'Facebook Marketplace',
        'condition': 'Usado - Aceptable',
        'price': 55.0,
      },
    ],
  ),
];

final Random _random = Random();

/// Picks one of the sample scenarios at random and returns it as the
/// "first guess" Product - exact model still unknown on purpose, so the
/// guidance flow (if this item needs one) kicks in the same way it would
/// for a real low-confidence guess.
Product randomGuess() {
  final ScanScenario scenario = _scenarios[_random.nextInt(_scenarios.length)];

  return Product(
    name: scenario.guessName,
    brand: scenario.brand,
    category: scenario.category,
    model: '',
    confidence: scenario.guessConfidence,
    priceMin: scenario.priceMin,
    priceMax: scenario.priceMax,
    scannedAt: 'Ahora',
    icon: scenario.icon,
    description: 'Version exacta no determinada todavia.',
    scenarioId: scenario.id,
    catalogImageAsset: scenario.coverImageAsset,
  );
}

ScanScenario? scenarioById(String? id) {
  if (id == null) return null;
  for (final ScanScenario scenario in _scenarios) {
    if (scenario.id == id) return scenario;
  }
  return null;
}

/// Extra photos needed for this scenario before it can be confirmed.
/// Empty when the first guess is already enough (e.g. a clear cover shot).
List<Map<String, String>> guidanceStepsFor(String? scenarioId) {
  return scenarioById(scenarioId)?.guidanceSteps ?? const [];
}

/// Similar listings for the scenario a product came from, or a generic
/// fallback when there isn't one (e.g. an item loaded from History,
/// since scenarioId isn't persisted to Supabase).
List<Map<String, dynamic>> listingsFor(String? scenarioId) {
  final ScanScenario? scenario = scenarioById(scenarioId);
  if (scenario != null) return scenario.listings;

  return const [
    {
      'title': 'Publicacion parecida 1',
      'platform': 'MercadoLibre',
      'condition': 'Usado - Bueno',
      'price': 0.0,
    },
  ];
}
