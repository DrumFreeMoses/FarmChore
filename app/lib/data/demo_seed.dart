import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/role_default_set.dart';
import 'package:farm_chore/domain/roles.dart';

/// Plausible Jacob Springs Farm chore lists, one default set per role.
///
/// Grounded in the farm site: grass-based Alpine Jersey milk, eggs, pork,
/// beef, lamb, chicken, heirloom grains, produce, comb honey, Farm Store.
/// Dairy runs 7 days a week; other roles vary.
/// Each chore has a due time, reminder, and escalation configured.
const List<RoleDefaultSet> farmDefaults = [
  RoleDefaultSet(
    role: FarmRole.milkers,
    chores: [
      ChoreDefault(
        title: 'Morning milking',
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        dueTime: '06:00',
        reminderMinutes: 15,
        escalationMinutes: 60,
      ),
      ChoreDefault(
        title: 'Evening milking',
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        dueTime: '17:00',
        reminderMinutes: 15,
        escalationMinutes: 60,
      ),
      ChoreDefault(
        title: 'Clean milking parlor',
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        dueTime: '07:30',
        reminderMinutes: 15,
        escalationMinutes: 45,
      ),
      ChoreDefault(
        title: 'Process milk & cream',
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        dueTime: '08:00',
        reminderMinutes: 15,
        escalationMinutes: 60,
      ),
    ],
  ),
  RoleDefaultSet(
    role: FarmRole.pourers,
    chores: [
      ChoreDefault(
        title: 'Bottle milk for shares',
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        dueTime: '08:30',
        reminderMinutes: 15,
        escalationMinutes: 60,
      ),
      ChoreDefault(
        title: 'Fill Farm Store milk fridge',
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        dueTime: '09:00',
        reminderMinutes: 15,
        escalationMinutes: 45,
      ),
      ChoreDefault(
        title: 'Wash bottles & equipment',
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        dueTime: '10:00',
        reminderMinutes: 15,
        escalationMinutes: 60,
      ),
    ],
  ),
  RoleDefaultSet(
    role: FarmRole.feeders,
    chores: [
      ChoreDefault(
        title: 'Feed cows hay & grain',
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        dueTime: '06:30',
        reminderMinutes: 15,
        escalationMinutes: 60,
      ),
      ChoreDefault(
        title: 'Feed pigs',
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        dueTime: '07:00',
        reminderMinutes: 15,
        escalationMinutes: 60,
      ),
      ChoreDefault(
        title: 'Feed chickens & collect eggs',
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        dueTime: '07:00',
        reminderMinutes: 15,
        escalationMinutes: 60,
      ),
      ChoreDefault(
        title: 'Check water troughs',
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        dueTime: '08:00',
        reminderMinutes: 15,
        escalationMinutes: 60,
      ),
    ],
  ),
  RoleDefaultSet(
    role: FarmRole.mechanics,
    chores: [
      ChoreDefault(
        title: 'Fix fence',
        weekdays: [1, 4],
        dueTime: '09:00',
        reminderMinutes: 30,
        escalationMinutes: 120,
      ),
      ChoreDefault(
        title: 'Equipment repair',
        weekdays: [2, 5],
        dueTime: '09:00',
        reminderMinutes: 30,
        escalationMinutes: 120,
      ),
      ChoreDefault(
        title: 'Sharpen tools',
        weekdays: [3],
        dueTime: '09:00',
        reminderMinutes: 30,
        escalationMinutes: 120,
      ),
      ChoreDefault(
        title: 'Tractor & vehicle check',
        weekdays: [6],
        dueTime: '08:00',
        reminderMinutes: 30,
        escalationMinutes: 120,
      ),
    ],
  ),
  RoleDefaultSet(
    role: FarmRole.farmers,
    chores: [
      ChoreDefault(
        title: 'Harvest vegetables in season',
        weekdays: [1, 3, 5],
        dueTime: '08:00',
        reminderMinutes: 30,
        escalationMinutes: 120,
      ),
      ChoreDefault(
        title: 'Garden weeding & mulching',
        weekdays: [2, 4],
        dueTime: '08:00',
        reminderMinutes: 30,
        escalationMinutes: 120,
      ),
      ChoreDefault(
        title: 'Grain & flour milling',
        weekdays: [6],
        dueTime: '09:00',
        reminderMinutes: 30,
        escalationMinutes: 120,
      ),
      ChoreDefault(
        title: 'Comb honey & bees',
        weekdays: [5],
        dueTime: '10:00',
        reminderMinutes: 30,
        escalationMinutes: 120,
      ),
    ],
  ),
  RoleDefaultSet(
    role: FarmRole.nonJsf,
    chores: [
      ChoreDefault(
        title: 'Restock Farm Store',
        weekdays: [1, 3, 5],
        dueTime: '09:00',
        reminderMinutes: 30,
        escalationMinutes: 120,
      ),
      ChoreDefault(
        title: 'Clean & organize projects',
        weekdays: [2, 4],
        dueTime: '09:00',
        reminderMinutes: 30,
        escalationMinutes: 120,
      ),
      ChoreDefault(
        title: 'Members pickup support',
        weekdays: [6],
        dueTime: '10:00',
        reminderMinutes: 30,
        escalationMinutes: 120,
      ),
    ],
  ),
];

/// Writes every default set (LWW: re-running replaces, never duplicates).
Future<void> seedFarmDefaults(ChoreRepository repository) async {
  for (final set in farmDefaults) {
    await repository.saveRoleDefaultSet(set);
  }
}
