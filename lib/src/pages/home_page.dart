import 'package:flutter/material.dart';

import '../models/product.dart';
import '../provider/product_provider.dart';
import '../utils/format_util.dart';
import '../utils/icon_string_util.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notificaciones',
            onPressed: () => Navigator.pushNamed(context, 'notifications'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _scanCard(context),
          const SizedBox(height: 16),
          _quickActions(context),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Escaneos recientes', () {
            Navigator.pushNamed(context, 'history');
          }),
          ..._recentItems(context),
        ],
      ),
    );
  }

  /// Accion principal: abrir la camara para identificar un producto.
  Widget _scanCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colors.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.photo_camera, size: 40, color: colors.onPrimaryContainer),
            const SizedBox(height: 12),
            Text(
              'Identificar un producto',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Saca una foto y la app reconoce la categoria, la marca y el '
              'modelo.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, 'camera'),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Abrir camara'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _actionTile(
            context,
            icon: Icons.qr_code_scanner,
            label: 'Codigo de barras',
            route: 'barcode',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionTile(
            context,
            icon: Icons.compare,
            label: 'Comparar estado',
            route: 'condition',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionTile(
            context,
            icon: Icons.history,
            label: 'Historial',
            route: 'history',
          ),
        ),
      ],
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(
    BuildContext context,
    String text,
    VoidCallback onSeeAll,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: Theme.of(context).textTheme.titleMedium),
        TextButton(onPressed: onSeeAll, child: const Text('Ver todo')),
      ],
    );
  }

  List<Widget> _recentItems(BuildContext context) {
    final List<Product> recent = productProvider.history().take(3).toList();

    return recent.map((product) {
      return Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: getIcon(product.icon, size: 32),
            title: Text(product.name),
            subtitle: Text('${product.category} - ${product.scannedAt}'),
            trailing: Text(
              '${money(product.priceMin)} - ${money(product.priceMax)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () => Navigator.pushNamed(
              context,
              'result',
              arguments: product,
            ),
          ),
          const Divider(height: 1),
        ],
      );
    }).toList();
  }
}
