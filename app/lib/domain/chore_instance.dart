import 'roles.dart';

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

  /// Canonical addressable id: `date|role|slug` (NIP-01 `d` tag).
  String get dTag => '${_isoDate(date)}|${role.id}|$slug';

  ChoreInstance copyWith({
    ChoreStatus? status,
    DateTime? completedAt,
    DateTime? deferredTo,
    String? assignee,
    ChoreType? type,
    String? title,
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
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
