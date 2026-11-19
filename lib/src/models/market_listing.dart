/// One comparable listing, from whichever marketplace found it.
class MarketListing {
  const MarketListing({
    required this.title,
    required this.price,
    required this.currency,
    required this.condition,
    required this.url,
    required this.imageUrl,
    required this.platform,
  });

  final String title;
  final double price;
  final String currency;
  final String condition;
  final String url;
  final String imageUrl;

  /// Which marketplace this came from ("eBay", "MercadoLibre"), shown in
  /// the UI so the user knows where a given reference price is from.
  final String platform;
}

/// The price picture built from a set of listings: the range, a
/// suggested price, and the listings it came from - regardless of which
/// marketplace provider produced them. See PriceComparisonService for how
/// a provider gets picked.
class MarketPriceReport {
  const MarketPriceReport({
    required this.query,
    required this.listings,
    required this.currency,
    required this.source,
  });

  final String query;
  final List<MarketListing> listings;
  final String currency;

  /// Display name of the marketplace that produced this report.
  final String source;

  bool get isEmpty => listings.isEmpty;

  List<double> get _sortedPrices {
    final List<double> prices =
        listings.map((listing) => listing.price).where((p) => p > 0).toList()
          ..sort();
    return prices;
  }

  double get minPrice {
    final List<double> prices = _sortedPrices;
    return prices.isEmpty ? 0 : prices.first;
  }

  double get maxPrice {
    final List<double> prices = _sortedPrices;
    return prices.isEmpty ? 0 : prices.last;
  }

  /// Median rather than mean: a single mispriced listing (a $900 sealed
  /// copy next to $40 loose discs) shouldn't drag the suggestion with it.
  double get medianPrice {
    final List<double> prices = _sortedPrices;
    if (prices.isEmpty) return 0;
    final int middle = prices.length ~/ 2;
    if (prices.length.isOdd) return prices[middle];
    return (prices[middle - 1] + prices[middle]) / 2;
  }

  int get sampleSize => _sortedPrices.length;
}
