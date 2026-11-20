import '../models/market_listing.dart';
import 'ebay_service.dart';
import 'mercadolibre_service.dart';

/// Raised only when every configured provider failed. Carries each
/// provider's own message so the user can tell what actually went wrong
/// rather than a generic "couldn't get prices".
class PriceLookupException implements Exception {
  const PriceLookupException(this.attempts);

  /// One line per provider that was tried, e.g. "eBay: ...".
  final List<String> attempts;

  String get message => attempts.isEmpty
      ? 'No hay ningun proveedor de precios configurado.'
      : attempts.join('\n');

  @override
  String toString() => message;
}

/// Picks a price provider and falls back automatically.
///
/// Today's reason this exists: eBay holds new developer accounts in
/// review before production calls work, so during that wait every eBay
/// call fails. Rather than surface that as a dead end, this tries eBay
/// first (it's the richer source - a full list of competing listings)
/// and falls back to MercadoLibre on any failure, including "not
/// configured yet" and "account still in review". Once eBay's review
/// clears, calls there start succeeding again and the fallback simply
/// stops triggering - no code change needed.
class PriceComparisonService {
  Future<MarketPriceReport> searchSimilar({
    required String query,
    bool isConsole = false,
  }) async {
    final List<String> failures = [];

    if (ebayService.isConfigured) {
      try {
        final MarketPriceReport report = await ebayService.searchSimilar(
          query: query,
          isConsole: isConsole,
        );
        // A clean 200 with zero matching items isn't an error, but it's
        // not useful either - worth letting the next provider try
        // before giving up, instead of treating "found nothing" the
        // same as "found something real".
        if (!report.isEmpty) return report;
        failures.add('eBay: no encontro publicaciones para esa busqueda.');
      } on EbayException catch (error) {
        failures.add('eBay: ${error.message}');
      } catch (error) {
        failures.add('eBay: $error');
      }
    } else {
      failures.add('eBay: no configurado.');
    }

    if (mercadoLibreService.isConfigured) {
      try {
        final MarketPriceReport report = await mercadoLibreService
            .searchSimilar(query: query, isConsole: isConsole);
        if (!report.isEmpty) return report;
        failures.add(
          'MercadoLibre: no encontro publicaciones para esa busqueda.',
        );
      } on MercadoLibreException catch (error) {
        failures.add('MercadoLibre: ${error.message}');
      } catch (error) {
        failures.add('MercadoLibre: $error');
      }
    } else {
      failures.add('MercadoLibre: no configurado.');
    }

    throw PriceLookupException(failures);
  }

  /// Same lookup, but never throws - used while identifying, where a
  /// missing price shouldn't block saving the product.
  Future<MarketPriceReport?> trySearchSimilar({
    required String query,
    bool isConsole = false,
  }) async {
    try {
      return await searchSimilar(query: query, isConsole: isConsole);
    } catch (_) {
      return null;
    }
  }
}

final PriceComparisonService priceComparisonService = PriceComparisonService();
