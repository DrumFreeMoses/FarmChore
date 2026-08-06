import 'dart:convert';

import 'roles.dart';
import '../nostr/nostr_event.dart';

/// Kind for a scheduled chore/task instance.
const int choreInstanceKind = 31501;

/// A chore is standard daily work; a task is auxiliary, one-off work.
enum ChoreType { chore, task }

/// Lifecycle of a scheduled item.
enum ChoreStatus {
  open,
  done,
  skipped,
  deferred,
  cancelled;

  bool get isOpen => this == open;
  bool get isDone => this == done;
  bool get isRemaining => this == open || this == deferred || this == skipped;
}

/// A scheduled chore or task instance for one role on one date (kind 31501).
class ChoreInstance {
  const ChoreInstance({
    required this.date,
    required this.role,
    required this.slug,
    required this.title,
    this.type = ChoreType.chore,
    this.status = ChoreStatus.open,
    this.completedAt,
    this.deferredTo,
    this.assignee,
    this.dueTime,
  });

  final DateTime date;
  final FarmRole role;
  final String slug;
  final String title;
  final ChoreType type;
  final ChoreStatus status;
  final DateTime? completedAt;
  final DateTime? deferredTo;
  final String? assignee;

  /// Optional due time in "HH:MM" format (e.g. "06:00").
  final String? dueTime;

  /// Whether this chore has a scheduled due time.
  bool get hasSchedule => dueTime != null;

  /// Whether this chore is overdue (past due time and still open).
  bool get isOverdue {
    if (!hasSchedule || !status.isOpen) return false;
    final now = DateTime.now();
    if (!isSameDay(now, date)) return false;
    return _nowMinutes > _dueMinutes;
  }

  /// Minutes past due (positive = overdue, negative = not yet due).
  int get minutesOverdue {
    if (!hasSchedule || !status.isOpen) return 0;
    final now = DateTime.now();
    if (!isSameDay(now, date)) return 0;
    return _nowMinutes - _dueMinutes;
  }

  int get _dueMinutes {
    final parts = dueTime!.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  int get _nowMinutes {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Canonical addressable id: `date|role|slug` (NIP-01 `d` tag).
  String get dTag => '${_isoDate(date)}|${role.id}|$slug';

  ChoreInstance copyWith({
    ChoreStatus? status,
    DateTime? completedAt,
    DateTime? deferredTo,
    String? assignee,
    ChoreType? type,
    String? title,
    String? dueTime,
  }) {
    return ChoreInstance(
      date: date,
      role: role,
      slug: slug,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      deferredTo: deferredTo ?? this.deferredTo,
      assignee: assignee ?? this.assignee,
      dueTime: dueTime ?? this.dueTime,
    );
  }

  ChoreInstance markDone() =>
      copyWith(status: ChoreStatus.done, completedAt: DateTime.now());

  ChoreInstance markSkipped() => _transition(ChoreStatus.skipped);

  ChoreInstance cancel() => _transition(ChoreStatus.cancelled);

  ChoreInstance deferTo(DateTime newDate) {
    if (status == ChoreStatus.done || status == ChoreStatus.cancelled) {
      throw StateError('cannot defer a $status chore');
    }
    return copyWith(status: ChoreStatus.deferred, deferredTo: newDate);
  }

  ChoreInstance _transition(ChoreStatus next) {
    if (status == ChoreStatus.done || status == ChoreStatus.cancelled) {
      throw StateError('cannot transition a $status chore to $next');
    }
    return copyWith(status: next);
  }

  /// Serializes as a signed-ready kind 31501 event. The caller signs and
  /// stores the result.
  NostrEvent toNostrEvent({
    required String pubKey,
    required int createdAt,
    String? farmPubkey,
    List<List<String>> extraTags = const [],
  }) {
    final content = jsonEncode({
      'title': title,
      'type': type.name,
      'status': status.name,
      if (deferredTo != null) 'deferredTo': _isoDate(deferredTo!),
      if (dueTime != null) 'dueTime': dueTime,
    });
    return NostrEvent(
      pubKey: pubKey,
      createdAt: createdAt,
      kind: choreInstanceKind,
      tags: [
        ['d', dTag],
        ['role', role.id],
        ['date', _isoDate(date)],
        if (farmPubkey != null) ['farm', farmPubkey],
        if (assignee != null) ['assignee', assignee!],
        ...extraTags,
      ],
      content: content,
    );
  }

  /// Parses a kind 31501 event back into an instance.
  factory ChoreInstance.fromNostrEvent(NostrEvent event) {
    if (event.kind != choreInstanceKind) {
      throw FormatException(
        'expected kind $choreInstanceKind, got ${event.kind}',
      );
    }
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(event.content) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('malformed instance content: $e');
    }
    final title = decoded['title'];
    if (title is! String || title.isEmpty) {
      throw const FormatException('instance needs a title');
    }
    final roleId = event.tags
        .where((t) => t.first == 'role')
        .map((t) => t[1])
        .firstOrNull;
    final role = roleId == null ? null : FarmRole.fromIdOrNull(roleId);
    if (role == null) {
      throw const FormatException('instance needs a valid role tag');
    }
    final date = event.tags
        .where((t) => t.first == 'date')
        .map((t) => t[1])
        .firstOrNull;
    if (date == null) {
      throw const FormatException('instance needs a date tag');
    }
    final dTag = event.tags
        .where((t) => t.first == 'd')
        .map((t) => t[1])
        .firstOrNull;
    final slug = dTag?.split('|').last;
    if (slug == null || slug.isEmpty) {
      throw const FormatException('instance needs a d tag with a slug');
    }
    final assignee = event.tags
        .where((t) => t.first == 'assignee')
        .map((t) => t[1])
        .firstOrNull;
    final status = ChoreStatus.values.asNameMap()[decoded['status']];
    final type = ChoreType.values.asNameMap()[decoded['type']];
    final deferredTo = decoded['deferredTo'];
    final dueTime = decoded['dueTime'] as String?;
    return ChoreInstance(
      date: _parseIsoDate(date),
      role: role,
      slug: slug,
      title: title,
      type: type ?? ChoreType.chore,
      status: status ?? ChoreStatus.open,
      deferredTo: deferredTo is String ? _parseIsoDate(deferredTo) : null,
      assignee: assignee,
      dueTime: dueTime,
    );
  }
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _parseIsoDate(String iso) {
  final parts = iso.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}
