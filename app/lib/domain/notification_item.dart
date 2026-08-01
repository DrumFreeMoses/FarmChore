import 'package:farm_chore/domain/roles.dart';

/// The type of notification event.
enum NotificationType { assigned, statusChange, headsUp }

/// A user-facing notification derived from the local event log.
///
/// Notifications are not stored as Nostr events — they are computed from
/// the existing event log and a read/unread flag kept locally.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.relatedInstanceId,
    this.role,
    this.read = false,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime timestamp;
  final String relatedInstanceId;
  final FarmRole? role;
  final bool read;

  NotificationItem copyWith({bool? read}) => NotificationItem(
    id: id,
    type: type,
    title: title,
    body: body,
    timestamp: timestamp,
    relatedInstanceId: relatedInstanceId,
    role: role,
    read: read ?? this.read,
  );
}
