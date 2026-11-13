import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';

/// Talks to the "notifications" table. Rows are created automatically
/// whenever a product gets identified (see ProductService callers);
/// there is no scheduled job checking prices yet, so "price changed"
/// alerts don't exist in the database for now.
class NotificationService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> create({
    required String title,
    required String body,
    String icon = 'devices_other',
    String? productId,
  }) async {
    await _client.from('notifications').insert({
      'title': title,
      'body': body,
      'icon': icon,
      'product_id': productId,
    });
  }

  Future<List<AppNotification>> fetchAll() async {
    final List<dynamic> rows = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false);

    return rows
        .map((row) => AppNotification.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) async {
    await _client.from('notifications').update({'unread': false}).eq('id', id);
  }

  Future<void> markAllRead() async {
    await _client
        .from('notifications')
        .update({'unread': false})
        .eq('unread', true);
  }
}

final notificationService = NotificationService();
