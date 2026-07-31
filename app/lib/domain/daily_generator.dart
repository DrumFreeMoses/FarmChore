import 'chore_instance.dart';
import 'role_default_set.dart';

/// Turns role default sets (kind 31500) into today's chore instances
/// (kind 31501).
abstract final class DailyGenerator {
  /// Generates open instances for [date] from each default that runs on
  /// that weekday. Sundays generate nothing (the farm rests).
  static List<ChoreInstance> generate({
    required List<RoleDefaultSet> defaults,
    required DateTime date,
  }) {
    final instances = <ChoreInstance>[];
    for (final set in defaults) {
      for (final chore in set.chores) {
        if (!chore.runsOnWeekday(date)) {
          continue;
        }
        instances.add(
          ChoreInstance(
            date: date,
            role: set.role,
            slug: slugify(chore.title),
            title: chore.title,
            assignee: chore.assigneeHint,
          ),
        );
      }
    }
    return instances;
  }

  /// Regenerates open instances on [date] for every instance deferred to
  /// that date (and only that date).
  static List<ChoreInstance> generateDeferred({
    required List<ChoreInstance> deferred,
    required DateTime date,
  }) {
    final instances = <ChoreInstance>[];
    for (final instance in deferred) {
      if (instance.status != ChoreStatus.deferred) {
        continue;
      }
      final to = instance.deferredTo;
      if (to == null || _sameDay(to, date)) {
        instances.add(
          ChoreInstance(
            date: date,
            role: instance.role,
            slug: instance.slug,
            title: instance.title,
            type: instance.type,
            assignee: instance.assignee,
          ),
        );
      }
    }
    return instances;
  }

  /// `"Clean the Stalls!"` -> `"clean-the-stalls"`.
  static String slugify(String title) {
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp('^-+|-+\$'), '');
    return slug;
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
