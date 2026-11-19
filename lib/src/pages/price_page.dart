import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/market_listing.dart';
import '../models/product.dart';
import '../services/price_comparison_service.dart';
import '../services/product_service.dart';
import '../utils/format_util.dart';

/// Real price comparison, from whichever marketplace actually answered
/// the search - see PriceComparisonService for how eBay/MercadoLibre are
/// picked between (eBay first, MercadoLibre as the automatic fallback).
///
/// Worth being precise about what these numbers are: eBay's Browse API
/// returns what sellers are currently ASKING, not what items sold for;
/// MercadoLibre's catalog price is the current winning offer on that
/// catalog entry, same idea. Neither is a "sold for" price, so the copy
/// here says "publicaciones activas" rather than implying realised sales.
class PricePage extends StatefulWidget {
  const PricePage({super.key});

  @override
  State<PricePage> createState() => _PricePageState();
}

class _PricePageState extends State<PricePage> {
  MarketPriceReport? _report;
  String? _error;
  bool _loading = true;
  bool _started = false;
  Product? _product;

  /// Kicked off from build (that's where the route arguments are), but
  /// deferred to after the frame: _load starts with a setState, which
  /// isn't allowed while a build is in progress.
  void _startOnce(Product product) {
    if (_started) return;
    _started = true;
    _product = product;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(product);
    });
  }

  Future<void> _load(Product product) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Fall back to the product name when no search query was stored (old
    // rows saved before this field existed).
    final String query =
        product.ebayQuery.isNotEmpty ? product.ebayQuery : product.name;

    try {
      final MarketPriceReport report = await priceComparisonService.searchSimilar(
        query: query,
        isConsole: product.isConsole,
      );

      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });

      // Keep the saved range in sync with what the market says now.
      if (!report.isEmpty && product.id != null) {
        await productService.updatePrices(
          product.id!,
          priceMin: report.minPrice,
          priceMax: report.maxPrice,
        );
      }
    } on PriceLookupException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron traer los precios: $error';
        _loading = false;
      });
    }
  }

  Future<void> _openListing(MarketListing listing) async {
    if (listing.url.isEmpty) return;
    final Uri uri = Uri.parse(listing.url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la publicacion.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Object? arguments = ModalRoute.of(context)?.settings.arguments;
    final Product? product = arguments is Product ? arguments : _product;

    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comparar precios')),
        body: const Center(child: Text('No hay un producto para comparar.')),
      );
    }

    _startOnce(product);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparar precios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loading ? null : () => _load(product),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(product),
        child: _body(context, product),
      ),
    );
  }

  Widget _body(BuildContext context, Product product) {
    if (_loading) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Icon(
            Icons.cloud_off,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: () => _load(product),
              child: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    final MarketPriceReport report = _report!;

    if (report.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.search_off, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '${report.source} no devolvio publicaciones para '
            '"${report.query}".',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Puede pasar con ediciones muy raras o regionales.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _rangeCard(context, product, report),
        const SizedBox(height: 24),
        Text(
          'Publicaciones activas en ${report.source}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Busqueda: "${report.query}"',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ...report.listings.map((listing) => _listingTile(context, listing)),
        const SizedBox(height: 16),
        Text(
          'Son precios que los vendedores estan PIDIENDO ahora mismo, no '
          'precios de venta cerrada. Sirven como referencia para ubicar tu '
          'publicacion.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _rangeCard(
    BuildContext context,
    Product product,
    MarketPriceReport report,
  ) {
    // Where the median sits inside the range, for the little bar.
    final double span = report.maxPrice - report.minPrice;
    final double position = span <= 0
        ? 0.5
        : ((report.medianPrice - report.minPrice) / span).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: Theme.of(context).textTheme.titleMedium),
            if (product.subtitle.isNotEmpty)
              Text(
                product.subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            Text(
              money(report.medianPrice),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const Text('Precio sugerido (mediana del mercado)'),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: position, minHeight: 8),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Min ${money(report.minPrice)}'),
                Text('Max ${money(report.maxPrice)}'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sobre ${report.sampleSize} publicaciones en ${report.currency} '
              '(${report.source}).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _listingTile(BuildContext context, MarketListing listing) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: listing.imageUrl.isEmpty
            ? const Icon(Icons.storefront_outlined)
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  listing.imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.storefront_outlined),
                ),
              ),
        title: Text(listing.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${listing.condition} - ${listing.platform}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(listing.price),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Icon(Icons.open_in_new, size: 14, color: Colors.grey),
          ],
        ),
        onTap: () => _openListing(listing),
      ),
    );
  }
}
