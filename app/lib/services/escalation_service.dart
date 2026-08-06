import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/heads_up.dart';

/// Checks for overdue chores and posts escalation heads-ups.
///
/// Escalation levels:
/// - 0–reminderMinutes: visual indicator on chore card (yellow/orange)
/// - reminderMinutes–escalationMinutes: heads-up to the role
/// - >escalationMinutes: heads-up to the whole farm
///
/// Each escalation is tagged to prevent duplicate posts.
class EscalationService {
  const EscalationService(this._repository);

  final ChoreRepository _repository;

  /// Runs the escalation check. Call on app open, refresh, or periodic timer.
  /// Returns the number of new escalations posted.
  Future<int> check() async {
    final today = DateTime.now();
    final instances = await _repository.loadInstancesForDate(today);
    final names = await _repository.loadMemberNames();
    final defaults = await _repository.loadBaseRoleDefaultSets();
    var posted = 0;

    for (final instance in instances) {
      if (!instance.hasSchedule || !instance.status.isOpen) continue;
      final minutesOverdue = instance.minutesOverdue;
      if (minutesOverdue <= 0) continue;

      // Find the default for this chore to get escalation config.
      final roleSet = defaults
          .where((s) => s.role == instance.role)
          .firstOrNull;
      final choreDefault = roleSet?.chores
          .where((c) => c.title == instance.title)
          .firstOrNull;

      final reminderMin = choreDefault?.reminderMinutes ?? 30;
      final escalationMin = choreDefault?.escalationMinutes ?? 120;

      final assigneeName = instance.assignee != null
          ? (names[instance.assignee!] ?? 'someone')
          : 'someone';

      // Level 2: Farm-wide escalation.
      if (minutesOverdue > escalationMin) {
        final tag = 'esc|${instance.dTag}|farm';
        if (!await _alreadyPosted(tag)) {
          await _repository.saveHeadsUp(
            'OVERDUE: "${instance.title}" was due at ${instance.dueTime} '
            'and is ${minutesOverdue}min overdue. '
            'Assigned to $assigneeName — ${instance.role.displayName} team, '
            'please follow up.',
            scope: null,
            type: HeadsUpType.alert,
            escalationTag: tag,
          );
          posted++;
        }
      }
      // Level 1: Role-scoped escalation.
      else if (minutesOverdue > reminderMin) {
        final tag = 'esc|${instance.dTag}|role';
        if (!await _alreadyPosted(tag)) {
          await _repository.saveHeadsUp(
            '"${instance.title}" is ${minutesOverdue}min overdue. '
            'Assigned to $assigneeName — ${instance.role.displayName} team, '
            'please check in.',
            scope: instance.role,
            type: HeadsUpType.alert,
            escalationTag: tag,
          );
          posted++;
        }
      }
    }
    return posted;
  }

  /// Checks if an escalation with the given tag has already been posted.
  Future<bool> _alreadyPosted(String tag) async {
    final headsUps = await _repository.loadHeadsUps();
    return headsUps.any((h) => h.escalationTag == tag);
  }
}
