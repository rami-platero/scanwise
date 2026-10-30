import 'package:flutter/material.dart';

import '../models/product.dart';
import '../provider/product_provider.dart';
import '../utils/format_util.dart';

/// Comparacion de precios: rango de referencia y publicaciones parecidas.
class PricePage extends StatelessWidget {
  const PricePage({super.key});

  @override
  Widget build(BuildContext context) {
    final Object? arguments = ModalRoute.of(context)?.settings.arguments;
    final Product product =
        arguments is Product ? arguments : productProvider.history().first;

    final List<Map<String, dynamic>> listings =
        productProvider.similarListings();

    return Scaffold(
      appBar: AppBar(title: const Text('Comparar precios')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _rangeCard(context, product),
          const SizedBox(height: 24),
          Text(
            'Publicaciones parecidas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._listingTiles(context, listings),
          const SizedBox(height: 16),
          Text(
            'Los precios son de referencia y se calculan con publicaciones '
            'activas de productos en estado similar.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _rangeCard(BuildContext context, Product product) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Text(
              money(product.suggestedPrice),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const Text('Precio sugerido'),
            const SizedBox(height: 16),
            // Barra que ubica el precio sugerido dentro del rango.
            const LinearProgressIndicator(value: 0.5, minHeight: 8),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Min ${money(product.priceMin)}'),
                Text('Max ${money(product.priceMax)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _listingTiles(
    BuildContext context,
    List<Map<String, dynamic>> listings,
  ) {
    return listings.map((listing) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const Icon(Icons.storefront_outlined),
          title: Text(listing['title'] as String),
          subtitle: Text(
            '${listing['platform']} - ${listing['condition']}',
          ),
          trailing: Text(
            money(listing['price'] as double),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }).toList();
  }
}
