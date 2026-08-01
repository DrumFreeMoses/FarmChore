import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/notification_item.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/theme/farm_theme.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key, required this.repository});

  final ChoreRepository repository;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationItem> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final notifications = await widget.repository.loadNotifications();
    setState(() {
      _notifications = notifications;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.any((n) => !n.read))
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No notifications yet'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) => _NotificationTile(
                  notification: _notifications[index],
                  onTap: () => _onTap(_notifications[index]),
                ),
              ),
            ),
    );
  }

  void _markAllRead() {
    setState(() {
      _notifications = [for (final n in _notifications) n.copyWith(read: true)];
    });
  }

  void _onTap(NotificationItem notification) {
    // TODO: navigate to the related chore/headsup screen
    // For now, mark as read
    setState(() {
      _notifications = [
        for (final n in _notifications)
          if (n.id == notification.id) n.copyWith(read: true) else n,
      ];
    });
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationItem notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _iconForType(notification.type, notification.role),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(notification.body),
      trailing: Text(
        _timeAgo(notification.timestamp),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: onTap,
    );
  }

  Widget _iconForType(NotificationType type, FarmRole? role) {
    final color = role != null ? roleAccent(role) : Colors.grey;
    final icon = switch (type) {
      NotificationType.assigned => Icons.person_add,
      NotificationType.statusChange => Icons.edit_note,
      NotificationType.headsUp => Icons.campaign,
    };
    return CircleAvatar(
      backgroundColor: color.withAlpha(40),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
