import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import 'auth_service.dart';

/// Talks to the "notifications" table. Rows are created automatically
/// whenever a product gets identified, and belong to the user who
/// created them - RLS enforces that server-side, and the user_id filters
/// here keep the queries honest too.
///
/// There is no scheduled job checking prices yet, so "price changed"
/// alerts don't exist in the database for now.
class NotificationService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> create({
    required String title,
    required String body,
    String icon = 'videogame',
    String? productId,
  }) async {
    final String? userId = authService.userId;
    if (userId == null) return;

    await _client.from('notifications').insert({
      'title': title,
      'body': body,
      'icon': icon,
      'product_id': productId,
      'user_id': userId,
    });
  }

  Future<List<AppNotification>> fetchAll() async {
    final String? userId = authService.userId;
    if (userId == null) return const [];

    final List<dynamic> rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return rows
        .map((row) => AppNotification.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) async {
    await _client.from('notifications').update({'unread': false}).eq('id', id);
  }

  Future<void> markAllRead() async {
    final String? userId = authService.userId;
    if (userId == null) return;

    await _client
        .from('notifications')
        .update({'unread': false})
        .eq('user_id', userId)
        .eq('unread', true);
  }
}

final notificationService = NotificationService();
