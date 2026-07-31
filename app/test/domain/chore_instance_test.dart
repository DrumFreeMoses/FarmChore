import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/roles.dart';

void main() {
  group('roles', () {
    test('contains the six farm roles in canonical order', () {
      expect(FarmRoles.all, [
        FarmRole.milkers,
        FarmRole.pourers,
        FarmRole.feeders,
        FarmRole.mechanics,
        FarmRole.farmers,
        FarmRole.nonJsf,
      ]);
    });

    test('each role has a machine and display name', () {
      for (final role in FarmRoles.all) {
        expect(role.id, isNotEmpty);
        expect(role.displayName, isNotEmpty);
      }
    });
  });

  group('ChoreInstance', () {
    final instance = ChoreInstance(
      date: DateTime(2026, 7, 31),
      role: FarmRole.milkers,
      slug: 'morning-milking',
      title: 'Morning milking',
      type: ChoreType.chore,
    );

    test('canonical d tag is date|role|slug', () {
      expect(instance.dTag, '2026-07-31|milkers|morning-milking');
    });

    test('starts open and completes, skips, defers, cancels', () {
      expect(instance.status, ChoreStatus.open);

      final done = instance.markDone();
      expect(done.status, ChoreStatus.done);
      expect(done.completedAt, isNotNull);

      final skipped = instance.markSkipped();
      expect(skipped.status, ChoreStatus.skipped);

      final deferred = instance.deferTo(DateTime(2026, 8, 1));
      expect(deferred.status, ChoreStatus.deferred);
      expect(deferred.deferredTo, DateTime(2026, 8, 1));

      final cancelled = instance.cancel();
      expect(cancelled.status, ChoreStatus.cancelled);
    });

    test('a done chore cannot be deferred', () {
      final done = instance.markDone();
      expect(() => done.deferTo(DateTime(2026, 8, 1)), throwsStateError);
    });

    test('chores and tasks are visually distinct types', () {
      expect(instance.type, ChoreType.chore);
      final task = instance.copyWith(type: ChoreType.task);
      expect(task.type, ChoreType.task);
    });
  });
}
