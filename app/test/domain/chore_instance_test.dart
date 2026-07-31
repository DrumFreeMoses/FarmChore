import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/nostr/nostr_event.dart';

void main() {
  final farmPubkey = 'f' * 64;
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

    test('roundtrips through a signed Nostr event (kind 31501)', () {
      final event = instance.toNostrEvent(
        pubKey: farmPubkey,
        createdAt: 1000,
        farmPubkey: farmPubkey,
      );
      expect(event.kind, 31501);
      expect(event.tags, [
        ['d', '2026-07-31|milkers|morning-milking'],
        ['role', 'milkers'],
        ['date', '2026-07-31'],
        ['farm', farmPubkey],
      ]);
      final decoded = ChoreInstance.fromNostrEvent(event);
      expect(decoded.date, DateTime(2026, 7, 31));
      expect(decoded.role, FarmRole.milkers);
      expect(decoded.slug, 'morning-milking');
      expect(decoded.title, 'Morning milking');
      expect(decoded.type, ChoreType.chore);
      expect(decoded.status, ChoreStatus.open);
      expect(decoded.assignee, isNull);
    });

    test('roundtrips a done, deferred instance with assignee', () {
      final done = instance
          .copyWith(
            status: ChoreStatus.deferred,
            deferredTo: DateTime(2026, 8, 3),
          )
          .deferTo(DateTime(2026, 8, 3))
          .copyWith(assignee: 'b' * 64);
      final event = done.toNostrEvent(pubKey: farmPubkey, createdAt: 1);
      final decoded = ChoreInstance.fromNostrEvent(event);
      expect(decoded.status, ChoreStatus.deferred);
      expect(decoded.deferredTo, DateTime(2026, 8, 3));
      expect(decoded.assignee, 'b' * 64);
    });

    test('rejects events of other kinds', () {
      final event = NostrEvent(pubKey: farmPubkey, createdAt: 1, kind: 31502);
      expect(
        () => ChoreInstance.fromNostrEvent(event),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an instance without a role tag', () {
      final event = NostrEvent(
        pubKey: farmPubkey,
        createdAt: 1,
        kind: 31501,
        content: '{"title":"x","type":"chore","status":"open"}',
        tags: [
          ['d', '2026-07-31|milkers|morning-milking'],
        ],
      );
      expect(
        () => ChoreInstance.fromNostrEvent(event),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects malformed content', () {
      final event = NostrEvent(
        pubKey: farmPubkey,
        createdAt: 1,
        kind: 31501,
        content: 'not json',
        tags: [
          ['d', '2026-07-31|milkers|morning-milking'],
          ['role', 'milkers'],
          ['date', '2026-07-31'],
        ],
      );
      expect(
        () => ChoreInstance.fromNostrEvent(event),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
