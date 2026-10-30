import 'package:flutter/material.dart';

import '../models/product.dart';
import '../provider/product_provider.dart';
import '../utils/format_util.dart';
import '../utils/icon_string_util.dart';

/// Lista de todos los productos escaneados.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  /// Copia local para poder borrar items de la lista.
  final List<Product> _products = productProvider.history();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: _products.isEmpty ? _emptyState(context) : _list(context),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Todavia no escaneaste ningun producto'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pushNamed(context, 'camera'),
            child: const Text('Escanear uno'),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    return ListView.separated(
      itemCount: _products.length,
      separatorBuilder: (BuildContext context, int i) =>
          const Divider(height: 1),
      itemBuilder: (BuildContext context, int i) {
        final Product product = _products[i];

        return Dismissible(
          key: Key('${product.name}-$i'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (DismissDirection direction) {
            setState(() => _products.removeAt(i));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${product.name} eliminado')),
            );
          },
          child: _productTile(context, product),
        );
      },
    );
  }

  Widget _productTile(BuildContext context, Product product) {
    final bool pending = !product.isExactModel;

    return ListTile(
      leading: getIcon(product.icon, size: 32),
      title: Text(product.name),
      subtitle: Text('${product.category} - ${product.scannedAt}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${money(product.priceMin)} - ${money(product.priceMax)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (pending)
            const Text(
              'Sin confirmar',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
        ],
      ),
      // Si quedo sin confirmar, se retoma la guia de fotos.
      onTap: () => Navigator.pushNamed(
        context,
        pending ? 'guidance' : 'result',
        arguments: product,
      ),
    );
  }
}
