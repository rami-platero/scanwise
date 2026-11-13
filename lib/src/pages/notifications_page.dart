import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../utils/icon_string_util.dart';

/// "Identification complete" alerts (READ + UPDATE to mark as read).
/// Rows are created automatically when a product gets saved - see
/// identifying_page.dart and guidance_page.dart. There is no scheduled
/// job checking market prices yet, so "price changed" alerts don't show
/// up here for now; that would need a server-side job, out of scope today.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<AppNotification>? _notifications;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _notifications = null;
    });

    try {
      final List<AppNotification> notifications =
          await notificationService.fetchAll();
      if (!mounted) return;
      setState(() => _notifications = notifications);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo cargar: $error');
    }
  }

  bool get _hasUnread =>
      _notifications?.any((n) => n.unread) ?? false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (_hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Marcar leidas'),
            ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (_notifications == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notifications!.isEmpty) {
      // RefreshIndicator needs a scrollable child, otherwise the
      // pull-down gesture has nothing to grab.
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: const Center(child: Text('No hay notificaciones todavia')),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _notifications!.length,
        separatorBuilder: (BuildContext context, int i) =>
            const Divider(height: 1),
        itemBuilder: (BuildContext context, int i) =>
            _tile(_notifications![i]),
      ),
    );
  }

  Widget _tile(AppNotification notification) {
    return ListTile(
      leading: getIcon(notification.icon, size: 28),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.unread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(notification.body),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            notification.time,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (notification.unread)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.circle, size: 8, color: Colors.blue),
            ),
        ],
      ),
      onTap: () => _markRead(notification),
    );
  }

  Future<void> _markRead(AppNotification notification) async {
    if (!notification.unread || notification.id == null) {
      Navigator.pushNamed(context, 'history');
      return;
    }

    // Update the local list right away for a snappy UI.
    setState(() {
      final int i = _notifications!.indexOf(notification);
      _notifications![i] = AppNotification(
        id: notification.id,
        productId: notification.productId,
        title: notification.title,
        body: notification.body,
        icon: notification.icon,
        unread: false,
        time: notification.time,
      );
    });

    try {
      await notificationService.markRead(notification.id!);
    } catch (_) {
      // Non-critical: worst case it shows as read until the next reload.
    }

    if (!mounted) return;
    Navigator.pushNamed(context, 'history');
  }

  Future<void> _markAllRead() async {
    try {
      await notificationService.markAllRead();
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $error')),
      );
    }
  }
}
