import '../utils/format_util.dart';

/// A row from the "notifications" table.
class AppNotification {
  const AppNotification({
    this.id,
    this.productId,
    required this.title,
    required this.body,
    required this.icon,
    required this.unread,
    required this.time,
  });

  final String? id;
  final String? productId;
  final String title;
  final String body;
  final String icon;
  final bool unread;
  final String time;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String?,
      productId: map['product_id'] as String?,
      title: map['title'] as String,
      body: map['body'] as String,
      icon: (map['icon'] as String?) ?? 'devices_other',
      unread: map['unread'] as bool? ?? true,
      time: formatScannedAt(DateTime.parse(map['created_at'] as String)),
    );
  }
}
