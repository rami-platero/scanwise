import '../models/product.dart';
import 'fake_catalog.dart' as catalog;

/// Sample data. The pieces that will later come from a real identification
/// service stay here, since there is no AI call yet.
class _ProductProvider {
  /// Result of the first scan: the AI recognizes the category and the
  /// brand, but not the exact version (confidence is low on purpose, so
  /// the interactive guidance flow can be tested). Picked at random from
  /// a handful of sample products - see fake_catalog.dart - instead of
  /// always returning the same one.
  Product firstGuess() => catalog.randomGuess();

  /// The "confirmed" version of whichever scenario this guess came from
  /// (brand/model/price/description), used once the guidance photos are
  /// all taken. Falls back to the guess itself if the scenario can't be
  /// found (shouldn't normally happen).
  Product confirmedFor(Product guess) {
    final catalog.ScanScenario? scenario =
        catalog.scenarioById(guess.scenarioId);
    if (scenario == null) return guess;

    return guess.copyWith(
      name: scenario.confirmedName,
      model: scenario.confirmedModel,
      confidence: scenario.confirmedConfidence,
      priceMin: scenario.priceMin,
      priceMax: scenario.priceMax,
      description: scenario.description,
    );
  }

  /// Similar listings for the scenario a product came from (or a generic
  /// fallback for items without one, e.g. loaded from History).
  List<Map<String, dynamic>> similarListings(String? scenarioId) =>
      catalog.listingsFor(scenarioId);

  /// Extra photos needed for whichever scenario this guess came from.
  /// Can be empty - not every item needs extra depth, same as a real
  /// recognition model would decide dynamically per product.
  List<Map<String, String>> guidanceStepsFor(String? scenarioId) =>
      catalog.guidanceStepsFor(scenarioId);

  /// Fallback sample history, used only when a page is opened without a
  /// real product in its route arguments (e.g. opening it directly while
  /// the real history in Supabase is still empty).
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
}

/// Single shared instance used from the pages, same pattern as
/// product_service / notification_service.
final productProvider = _ProductProvider();
