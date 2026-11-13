import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';

/// The only place in the app that talks to the "products" table in
/// Supabase. Each method is a CRUD operation:
///   create -> INSERT, fetchHistory -> SELECT,
///   updateListing -> UPDATE, delete -> DELETE.
class ProductService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Saves a freshly identified product. Returns the row as created
  /// (with its id and scanned_at filled in by the database), keeping the
  /// local-only barcodeValue/scenarioId that don't live in Supabase.
  Future<Product> create(Product product) async {
    final Product persisted = await _persistPhoto(product);

    final Map<String, dynamic> row = await _client
        .from('products')
        .insert(persisted.toInsertMap())
        .select()
        .single();

    return Product.fromMap(row).copyWith(
      barcodeValue: persisted.barcodeValue,
      scenarioId: persisted.scenarioId,
    );
  }

  /// If this product has a real captured photo and no curated cover,
  /// copies it from image_picker's temporary location into the app's
  /// own permanent storage folder. Without this, the photo would point
  /// at a temp file the OS can clear at any time - which is exactly why
  /// it used to disappear once the product showed up again in History.
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
      final File saved = await File(
        product.photoPath!,
      ).copy('${photosDir.path}/$fileName');

      return product.copyWith(photoPath: saved.path);
    } catch (_) {
      // Worst case, keep the original (temp) path - still shows on this
      // screen, it just might not survive an app restart.
      return product;
    }
  }

  /// Fetches the whole history, most recent first.
  Future<List<Product>> fetchHistory() async {
    final List<dynamic> rows = await _client
        .from('products')
        .select()
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
    await _client.from('products').update({
      'name': name,
      'description': description,
      'price_min': priceMin,
      'price_max': priceMax,
    }).eq('id', id);
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

/// Single shared instance used from the pages, same pattern as
/// productProvider.
final productService = ProductService();
