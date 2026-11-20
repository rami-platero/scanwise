import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import 'auth_service.dart';

/// The only place in the app that talks to the "products" table in
/// Supabase. Each method is a CRUD operation:
///   create -> INSERT, fetchHistory -> SELECT,
///   updateListing -> UPDATE, delete -> DELETE.
///
/// Every row belongs to the logged-in user. RLS enforces that on the
/// server; the user_id filters here mirror it on the client.
class ProductService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Saves a freshly identified product, keeping the local-only
  /// barcodeValue/scenarioId that don't live in Supabase.
  Future<Product> create(Product product) async {
    final String? userId = authService.userId;
    if (userId == null) {
      throw Exception('Tenes que iniciar sesion para guardar un producto.');
    }

    final Product persisted = await _persistPhoto(product);

    final Map<String, dynamic> row = await _client
        .from('products')
        .insert({...persisted.toInsertMap(), 'user_id': userId})
        .select()
        .single();

    return Product.fromMap(row).copyWith(
      barcodeValue: persisted.barcodeValue,
      scenarioId: persisted.scenarioId,
    );
  }

  /// If this product has a real captured photo and no bundled cover,
  /// copies it from image_picker's temporary location into the app's own
  /// permanent storage folder. Without this, the photo would point at a
  /// temp file the OS can clear at any time - which is why it used to
  /// disappear once the product showed up again in History.
  Future<Product> _persistPhoto(Product product) async {
    if (product.catalogImageAsset != null || product.photoPath == null) {
      return product;
    }

    try {
      final Directory docsDir = await getApplicationDocumentsDirectory();
      final Directory photosDir = Directory('${docsDir.path}/scan_photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      final String extension = product.photoPath!.split('.').last;
      final String fileName =
          '${DateTime.now().microsecondsSinceEpoch}.$extension';
      final File saved = await File(product.photoPath!)
          .copy('${photosDir.path}/$fileName');

      return product.copyWith(photoPath: saved.path);
    } catch (_) {
      // Worst case, keep the original (temp) path - still shows on this
      // screen, it just might not survive an app restart.
      return product;
    }
  }

  /// Looks for an existing row with the same title and platform, so the
  /// save flow can warn before silently creating what might be an
  /// accidental re-scan. Not a hard duplicate check: two real copies of
  /// the same game are a legitimate case this can't rule out, since
  /// there's no serial number on a mass-produced disc telling them
  /// apart - it just flags the common case for the user to confirm.
  Future<Product?> findPossibleDuplicate({
    required String name,
    required String platform,
  }) async {
    final String? userId = authService.userId;
    if (userId == null || name.isEmpty) return null;

    final List<dynamic> rows = await _client
        .from('products')
        .select()
        .eq('user_id', userId)
        .ilike('name', name)
        .eq('platform', platform)
        .limit(1);

    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first as Map<String, dynamic>);
  }

  /// Fetches this user's history, most recent first.
  Future<List<Product>> fetchHistory() async {
    final String? userId = authService.userId;
    if (userId == null) return const [];

    final List<dynamic> rows = await _client
        .from('products')
        .select()
        .eq('user_id', userId)
        .order('scanned_at', ascending: false);

    return rows
        .map((row) => Product.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Updates the listing data (title, description and price) that the
  /// user edited by hand on the "Listing" screen.
  Future<void> updateListing(
    String id, {
    required String name,
    required String description,
    required double priceMin,
    required double priceMax,
  }) async {
    await _client
        .from('products')
        .update({
          'name': name,
          'description': description,
          'price_min': priceMin,
          'price_max': priceMax,
        })
        .eq('id', id);
  }

  /// Stores a refreshed price range from eBay against a saved product.
  Future<void> updatePrices(
    String id, {
    required double priceMin,
    required double priceMax,
  }) async {
    await _client
        .from('products')
        .update({'price_min': priceMin, 'price_max': priceMax})
        .eq('id', id);
  }

  /// Deletes the row and, if it had a real photo copied to local
  /// storage, that file too - otherwise those would just pile up unused.
  Future<void> delete(Product product) async {
    if (product.id != null) {
      await _client.from('products').delete().eq('id', product.id!);
    }

    if (product.photoPath != null) {
      try {
        final File file = File(product.photoPath!);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Not worth failing the delete over a leftover file.
      }
    }
  }
}

final productService = ProductService();
