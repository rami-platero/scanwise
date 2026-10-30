import 'package:flutter/material.dart';

import '../provider/product_provider.dart';
import '../utils/icon_string_util.dart';

/// Avisos de identificacion completada y de cambios de precio.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<Map<String, dynamic>> _notifications =
      productProvider.notifications();

  int get _unreadCount =>
      _notifications.where((n) => n['unread'] == true).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Marcar leidas'),
            ),
        ],
      ),
      body: ListView.separated(
        itemCount: _notifications.length,
        separatorBuilder: (BuildContext context, int i) =>
            const Divider(height: 1),
        itemBuilder: (BuildContext context, int i) => _tile(i),
      ),
    );
  }

  Widget _tile(int i) {
    final Map<String, dynamic> notification = _notifications[i];
    final bool unread = notification['unread'] == true;

    return ListTile(
      leading: getIcon(notification['icon'] as String, size: 28),
      title: Text(
        notification['title'] as String,
        style: TextStyle(
          fontWeight: unread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(notification['body'] as String),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            notification['time'] as String,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (unread)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.circle, size: 8, color: Colors.blue),
            ),
        ],
      ),
      // Al abrir el aviso se marca como leido y se va al producto.
      onTap: () {
        setState(() => notification['unread'] = false);
        Navigator.pushNamed(context, 'history');
      },
    );
  }

  void _markAllRead() {
    setState(() {
      for (final Map<String, dynamic> notification in _notifications) {
        notification['unread'] = false;
      }
    });
  }
}
