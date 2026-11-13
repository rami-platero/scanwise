import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../utils/format_util.dart';
import '../utils/icon_string_util.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with RouteAware {
  /// Kept in state (instead of calling fetchHistory() straight from
  /// build) so pull-to-refresh has something to replace with a new call.
  late Future<List<Product>> _recentFuture = productService.fetchHistory();

  @override
  void initState() {
    super.initState();
    _checkLostPhoto();
  }

  /// On some Android phones, opening the native camera app can make the
  /// OS kill this app in the background to free memory. When that
  /// happens, Flutter restarts clean on this route - which looks like
  /// "it sent me back to the main screen" - and the photo result would
  /// otherwise just be lost. image_picker keeps it recoverable through
  /// this call; if there's one waiting, we resume the flow with it
  /// instead of silently dropping it.
  Future<void> _checkLostPhoto() async {
    try {
      final LostDataResponse response = await ImagePicker().retrieveLostData();
      if (response.isEmpty || response.file == null) return;
      if (!mounted) return;

      Navigator.pushNamed(
        context,
        'identifying',
        arguments: {'photoPath': response.file!.path},
      );
    } catch (_) {
      // Not worth surfacing an error for a best-effort recovery check.
    }
  }

  Future<void> _refresh() async {
    final Future<List<Product>> next = productService.fetchHistory();
    setState(() => _recentFuture = next);
    await next;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Called when Home becomes visible again after a route pushed on top
  /// of it (camera, result, etc.) gets popped - exactly when a product
  /// may have just been created or deleted elsewhere.
  @override
  void didPopNext() => _refresh();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notificaciones',
            onPressed: () => Navigator.pushNamed(context, 'notifications'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _scanCard(context),
            const SizedBox(height: 16),
            _quickActions(context),
            const SizedBox(height: 24),
            _sectionTitle(context, 'Escaneos recientes', () {
              Navigator.pushNamed(context, 'history');
            }),
            _recentItems(context),
          ],
        ),
      ),
    );
  }

  /// Main action: open the camera to identify a product.
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

  /// Top 3 most recent products, read straight from Supabase.
  Widget _recentItems(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _recentFuture,
      builder: (BuildContext context, AsyncSnapshot<List<Product>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No se pudo cargar: ${snapshot.error}'),
          );
        }

        final List<Product> recent =
            (snapshot.data ?? const <Product>[]).take(3).toList();

        if (recent.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Todavia no escaneaste ningun producto.'),
          );
        }

        return Column(
          children: recent.map((product) => _recentTile(context, product)).toList(),
        );
      },
    );
  }

  Widget _recentTile(BuildContext context, Product product) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _thumbnail(product),
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
  }

  /// Same priority as result_page/history_page: curated cover, then the
  /// real (persisted) photo, then the icon.
  Widget _thumbnail(Product product) {
    final BorderRadius radius = BorderRadius.circular(8);

    if (product.catalogImageAsset != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          product.catalogImageAsset!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }

    if (product.photoPath != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(product.photoPath!),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }

    return getIcon(product.icon, size: 32);
  }
}
