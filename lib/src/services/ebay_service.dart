import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/market_listing.dart';

/// Raised when the price lookup fails. Message is user-facing Spanish.
class EbayException implements Exception {
  const EbayException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Looks up comparable listings on eBay to build a reference price.
///
/// Note on what these prices mean: the Browse API returns ACTIVE
/// listings, i.e. what sellers are currently asking - not what items
/// actually sold for. Completed-sale prices come from the Marketplace
/// Insights API, which needs separate approval from eBay. The UI says
/// "publicaciones activas" for that reason.
///
/// New eBay developer accounts go through an account review that eBay
/// says takes "at least one business day" before production API access
/// works - see PriceComparisonService for the MercadoLibre fallback used
/// while that's pending.
class EbayService {
  /// Video Games & Consoles -> Video Games.
  static const String _categoryGames = '139973';

  /// Video Games & Consoles -> Video Game Consoles.
  static const String _categoryConsoles = '139971';

  String get _apiHost =>
      ebayUseSandbox ? 'api.sandbox.ebay.com' : 'api.ebay.com';

  bool get isConfigured =>
      ebayClientId.isNotEmpty &&
      !ebayClientId.startsWith('YOUR-') &&
      ebayClientSecret.isNotEmpty &&
      !ebayClientSecret.startsWith('YOUR-');

  String? _accessToken;
  DateTime? _tokenExpiry;

  /// Fetches an application access token (client credentials grant) and
  /// keeps it until shortly before it expires.
  Future<String> _ensureToken() async {
    final DateTime now = DateTime.now();
    if (_accessToken != null &&
        _tokenExpiry != null &&
        now.isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    final String basicAuth =
        base64Encode(utf8.encode('$ebayClientId:$ebayClientSecret'));

    final http.Response response = await http
        .post(
          Uri.https(_apiHost, '/identity/v1/oauth2/token'),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': 'Basic $basicAuth',
          },
          body: {
            'grant_type': 'client_credentials',
            'scope': 'https://api.ebay.com/oauth/api_scope',
          },
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw const EbayException(
            'eBay tardo demasiado en responder.',
          ),
        );

    if (response.statusCode == 403) {
      // The common case right after creating a developer account: eBay
      // reviews new accounts before production access works.
      throw const EbayException(
        'La cuenta de eBay todavia esta en revision (puede tardar al menos '
        'un dia habil). Mientras tanto se usa MercadoLibre.',
      );
    }

    if (response.statusCode != 200) {
      throw EbayException(
        'No se pudo autenticar con eBay (${response.statusCode}). '
        'Revisa el Client ID y el Client Secret.',
      );
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    _accessToken = body['access_token'] as String?;
    final int expiresIn = (body['expires_in'] as num?)?.toInt() ?? 7200;
    // Renew a minute early so a request can't die mid-flight.
    _tokenExpiry = now.add(Duration(seconds: expiresIn - 60));

    if (_accessToken == null) {
      throw const EbayException('eBay no devolvio un token de acceso.');
    }

    return _accessToken!;
  }

  /// Searches comparable listings for [query].
  ///
  /// [isConsole] picks the right category so a search for "PlayStation 2"
  /// returns consoles rather than every game for the platform.
  Future<MarketPriceReport> searchSimilar({
    required String query,
    bool isConsole = false,
    int limit = 20,
  }) async {
    if (!isConfigured) {
      throw const EbayException(
        'Faltan las credenciales de eBay. Completa '
        'lib/src/config/api_config.dart.',
      );
    }

    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw const EbayException('No hay una busqueda para comparar precios.');
    }

    final String token = await _ensureToken();

    final Uri uri = Uri.https(_apiHost, '/buy/browse/v1/item_summary/search', {
      'q': trimmed,
      'category_ids': isConsole ? _categoryConsoles : _categoryGames,
      // Fixed-price listings only: live auction prices mid-bid aren't a
      // meaningful reference point for what something is worth.
      'filter': 'buyingOptions:{FIXED_PRICE}',
      'sort': 'price',
      'limit': '$limit',
    });

    final http.Response response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'X-EBAY-C-MARKETPLACE-ID': ebayMarketplaceId,
        'Accept': 'application/json',
      },
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () =>
          throw const EbayException('eBay tardo demasiado en responder.'),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      // Token might have been revoked early, or the account is still
      // under eBay's review; drop the cached token either way so the
      // next call starts clean.
      _accessToken = null;
      throw const EbayException(
        'eBay rechazo la consulta (cuenta en revision o token invalido).',
      );
    }

    if (response.statusCode != 200) {
      throw EbayException(
        'eBay devolvio un error (${response.statusCode}).',
      );
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    final List<dynamic> summaries =
        (body['itemSummaries'] as List?) ?? const [];

    final List<MarketListing> listings = summaries
        .whereType<Map>()
        .map((item) => _toListing(item.cast<String, dynamic>()))
        .where((listing) => listing.price > 0)
        .toList();

    return MarketPriceReport(
      query: trimmed,
      listings: listings,
      currency: listings.isEmpty ? 'USD' : listings.first.currency,
      source: 'eBay',
    );
  }

  MarketListing _toListing(Map<String, dynamic> json) {
    final Map<String, dynamic> priceNode =
        (json['price'] as Map?)?.cast<String, dynamic>() ?? const {};

    return MarketListing(
      title: (json['title'] ?? '').toString(),
      price: double.tryParse((priceNode['value'] ?? '').toString()) ?? 0,
      currency: (priceNode['currency'] ?? 'USD').toString(),
      condition: (json['condition'] ?? 'Sin especificar').toString(),
      url: (json['itemWebUrl'] ?? '').toString(),
      imageUrl: ((json['image'] as Map?)?['imageUrl'] ?? '').toString(),
      platform: 'eBay',
    );
  }

  /// Same search, but never throws - returns null when the lookup fails.
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

final EbayService ebayService = EbayService();
