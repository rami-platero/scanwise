import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/market_listing.dart';

/// Raised when the price lookup fails. Message is user-facing Spanish.
class MercadoLibreException implements Exception {
  const MercadoLibreException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Looks up comparable prices on MercadoLibre.
///
/// Unlike eBay's Browse API, MercadoLibre no longer offers free-text
/// search across every active listing to third-party apps - that was
/// restricted a while back. What's still available is the **Catalog
/// Products** API: `/products/search` matches a query against
/// MercadoLibre's catalogued products (the canonical listing multiple
/// sellers compete on), and each match's `buy_box_winner` carries the
/// current best price for it. That means:
///   - Good coverage for consoles and mainstream/re-released games.
///   - Weaker coverage for obscure regional/retro variants, which often
///     aren't catalogued as a single canonical product.
///   - Each match is ONE price point (the winning offer), not many
///     competing listings the way eBay's search returns - so the "range"
///     here is the spread across different matched catalog entries,
///     not across sellers of the exact same item.
///
/// Built from MercadoLibre's documentation rather than a live-tested
/// call (their docs site blocks automated fetches) - the field names
/// below may need adjusting once you run this against a real account.
class MercadoLibreService {
  bool get isConfigured =>
      mercadoLibreClientId.isNotEmpty &&
      !mercadoLibreClientId.startsWith('YOUR-') &&
      mercadoLibreClientSecret.isNotEmpty &&
      !mercadoLibreClientSecret.startsWith('YOUR-');

  String? _accessToken;
  DateTime? _tokenExpiry;

  /// Client-credentials tokens are app-level (not tied to a user) and
  /// last 6 hours; cached the same way as the eBay token.
  Future<String> _ensureToken() async {
    final DateTime now = DateTime.now();
    if (_accessToken != null &&
        _tokenExpiry != null &&
        now.isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    final http.Response response = await http
        .post(
          Uri.https('api.mercadolibre.com', '/oauth/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'client_credentials',
            'client_id': mercadoLibreClientId,
            'client_secret': mercadoLibreClientSecret,
          },
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw const MercadoLibreException(
            'MercadoLibre tardo demasiado en responder.',
          ),
        );

    if (response.statusCode != 200) {
      throw MercadoLibreException(
        'No se pudo autenticar con MercadoLibre (${response.statusCode}). '
        'Revisa el Client ID y el Client Secret.',
      );
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    _accessToken = body['access_token'] as String?;
    final int expiresIn = (body['expires_in'] as num?)?.toInt() ?? 21600;
    _tokenExpiry = now.add(Duration(seconds: expiresIn - 60));

    if (_accessToken == null) {
      throw const MercadoLibreException(
        'MercadoLibre no devolvio un token de acceso.',
      );
    }

    return _accessToken!;
  }

  Future<MarketPriceReport> searchSimilar({
    required String query,
    bool isConsole = false,
    int limit = 20,
  }) async {
    if (!isConfigured) {
      throw const MercadoLibreException(
        'Faltan las credenciales de MercadoLibre. Completa '
        'lib/src/config/api_config.dart.',
      );
    }

    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw const MercadoLibreException(
        'No hay una busqueda para comparar precios.',
      );
    }

    final String token = await _ensureToken();

    final Uri uri = Uri.https('api.mercadolibre.com', '/products/search', {
      'status': 'active',
      'site_id': mercadoLibreSiteId,
      'q': trimmed,
      'limit': '$limit',
    });

    final http.Response response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw const MercadoLibreException(
        'MercadoLibre tardo demasiado en responder.',
      ),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      _accessToken = null;
      throw const MercadoLibreException(
        'MercadoLibre rechazo la consulta (token invalido o sin permiso).',
      );
    }

    if (response.statusCode != 200) {
      throw MercadoLibreException(
        'MercadoLibre devolvio un error (${response.statusCode}).',
      );
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    final List<dynamic> results = (body['results'] as List?) ?? const [];

    final List<MarketListing> listings = results
        .whereType<Map>()
        .map((item) => _toListing(item.cast<String, dynamic>()))
        .where((listing) => listing != null)
        .cast<MarketListing>()
        .toList();

    return MarketPriceReport(
      query: trimmed,
      listings: listings,
      currency: listings.isEmpty ? _currencyFor(mercadoLibreSiteId) : listings.first.currency,
      source: 'MercadoLibre',
    );
  }

  /// A catalog match's price lives in `buy_box_winner` (the current best
  /// offer); it's null when nothing is actively competing on that catalog
  /// entry, in which case this result is skipped rather than guessed at.
  MarketListing? _toListing(Map<String, dynamic> json) {
    final Map<String, dynamic>? buyBox =
        (json['buy_box_winner'] as Map?)?.cast<String, dynamic>();
    if (buyBox == null) return null;

    final double price = (buyBox['price'] as num?)?.toDouble() ?? 0;
    if (price <= 0) return null;

    final String id = (json['id'] ?? '').toString();
    final List<dynamic> pictures = (json['pictures'] as List?) ?? const [];
    final String imageUrl = pictures.isNotEmpty && pictures.first is Map
        ? ((pictures.first as Map)['url'] ?? '').toString()
        : '';

    return MarketListing(
      title: (json['name'] ?? '').toString(),
      price: price,
      currency: (buyBox['currency_id'] ?? _currencyFor(mercadoLibreSiteId))
          .toString(),
      condition: _conditionLabel((buyBox['condition'] ?? '').toString()),
      url: id.isEmpty ? '' : 'https://www.mercadolibre.${_tldFor(mercadoLibreSiteId)}/p/$id',
      imageUrl: imageUrl,
      platform: 'MercadoLibre',
    );
  }

  String _conditionLabel(String condition) {
    switch (condition) {
      case 'new':
        return 'Nuevo';
      case 'used':
        return 'Usado';
      default:
        return condition.isEmpty ? 'Sin especificar' : condition;
    }
  }

  /// Domain suffix per site, for building a product page URL.
  String _tldFor(String siteId) {
    switch (siteId) {
      case 'MLM':
        return 'com.mx';
      case 'MLB':
        return 'com.br';
      case 'MCO':
        return 'com.co';
      case 'MLC':
        return 'cl';
      case 'MLU':
        return 'com.uy';
      case 'MPE':
        return 'com.pe';
      case 'MEC':
        return 'com.ec';
      case 'MLV':
        return 'com.ve';
      case 'MLA':
      default:
        return 'com.ar';
    }
  }

  String _currencyFor(String siteId) {
    switch (siteId) {
      case 'MLM':
        return 'MXN';
      case 'MLB':
        return 'BRL';
      case 'MCO':
        return 'COP';
      case 'MLC':
        return 'CLP';
      case 'MLU':
        return 'UYU';
      case 'MPE':
        return 'PEN';
      case 'MLA':
      default:
        return 'ARS';
    }
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

final MercadoLibreService mercadoLibreService = MercadoLibreService();
