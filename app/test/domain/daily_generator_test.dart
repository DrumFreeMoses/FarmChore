import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/daily_generator.dart';
import 'package:farm_chore/domain/role_default_set.dart';
import 'package:farm_chore/domain/roles.dart';

void main() {
  final friday = DateTime(2026, 7, 31); // Friday, weekday 5
  final sunday = DateTime(2026, 8, 2); // Sunday, weekday 7

  const milkersDefaults = RoleDefaultSet(
    role: FarmRole.milkers,
    chores: [
      ChoreDefault(title: 'Morning milking', weekdays: [1, 2, 3, 4, 5, 6]),
      ChoreDefault(title: 'Clean stalls', weekdays: [1, 4]),
      ChoreDefault(title: 'Fix broken gate', weekdays: [6]),
    ],
  );

  group('DailyGenerator.generate', () {
    test('generates instances only for defaults that run today', () {
      final instances = DailyGenerator.generate(
        defaults: [milkersDefaults],
        date: friday,
      );
      expect(instances.map((i) => i.title), [
        'Morning milking',
      ]); // Fri is weekday 5
    });

    test('generates nothing on Sunday (rest day)', () {
      final instances = DailyGenerator.generate(
        defaults: [milkersDefaults],
        date: sunday,
      );
      expect(instances, isEmpty);
    });

    test('skips a role with no matching defaults but keeps others', () {
      const farmers = RoleDefaultSet(
        role: FarmRole.farmers,
        chores: [
          ChoreDefault(title: 'Garden work', weekdays: [3]),
        ],
      );
      final instances = DailyGenerator.generate(
        defaults: [milkersDefaults, farmers],
        date: friday,
      );
      expect(instances.single.title, 'Morning milking');
    });

    test('empty defaults produce no instances', () {
      expect(
        DailyGenerator.generate(defaults: const [], date: friday),
        isEmpty,
      );
    });

    test('instances carry date, role, type and open status', () {
      final instance = DailyGenerator.generate(
        defaults: [milkersDefaults],
        date: friday,
      ).single;
      expect(instance.date, friday);
      expect(instance.role, FarmRole.milkers);
      expect(instance.type, ChoreType.chore);
      expect(instance.status, ChoreStatus.open);
      expect(instance.dTag, '2026-07-31|milkers|morning-milking');
    });

    test('carries assigneeHint onto the instance', () {
      const withHint = RoleDefaultSet(
        role: FarmRole.feeders,
        chores: [
          ChoreDefault(
            title: 'Feed calves',
            weekdays: [1, 2, 3, 4, 5, 6],
            assigneeHint: 'Sana',
          ),
        ],
      );
      final instance = DailyGenerator.generate(
        defaults: [withHint],
        date: friday,
      ).single;
      expect(instance.assignee, 'Sana');
    });
  });

  group('DailyGenerator.generateDeferred', () {
    test('resurfaces deferred instances on their deferredTo date', () {
      final deferred = ChoreInstance(
        date: friday,
        role: FarmRole.milkers,
        slug: 'morning-milking',
        title: 'Morning milking',
        status: ChoreStatus.deferred,
        deferredTo: DateTime(2026, 8, 3), // Monday
      );
      final generated = DailyGenerator.generateDeferred(
        deferred: [deferred],
        date: DateTime(2026, 8, 3),
      );
      expect(generated.single.title, 'Morning milking');
      expect(generated.single.status, ChoreStatus.open);
      expect(generated.single.date, DateTime(2026, 8, 3));
      expect(generated.single.deferredTo, isNull);
      expect(generated.single.dTag, '2026-08-03|milkers|morning-milking');
    });

    test('ignores deferred instances whose date is not today', () {
      final deferred = ChoreInstance(
        date: friday,
        role: FarmRole.milkers,
        slug: 'morning-milking',
        title: 'Morning milking',
        status: ChoreStatus.deferred,
        deferredTo: DateTime(2026, 8, 4),
      );
      expect(
        DailyGenerator.generateDeferred(
          deferred: [deferred],
          date: DateTime(2026, 8, 3),
        ),
        isEmpty,
      );
    });

    test('ignores non-deferred instances', () {
      final open = ChoreInstance(
        date: friday,
        role: FarmRole.milkers,
        slug: 'morning-milking',
        title: 'Morning milking',
      );
      expect(
        DailyGenerator.generateDeferred(
          deferred: [open],
          date: DateTime(2026, 8, 3),
        ),
        isEmpty,
      );
    });
  });

  group('slugify', () {
    test('lowercases, kebab-cases, strips punctuation', () {
      expect(DailyGenerator.slugify('Clean the Stalls!'), 'clean-the-stalls');
      expect(
        DailyGenerator.slugify('Feed 10 calves: morning'),
        'feed-10-calves-morning',
      );
      expect(DailyGenerator.slugify('  Trim  hooves  '), 'trim-hooves');
      expect(DailyGenerator.slugify('Milking (AM)'), 'milking-am');
    });
  });
}
