import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/domain/role_default_set.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/nostr/nostr_event.dart';

void main() {
  final farmPubkey = 'a' * 64;

  group('ChoreDefault', () {
    test('roundtrips through JSON', () {
      const chore = ChoreDefault(
        title: 'Morning milking',
        weekdays: [1, 2, 3, 4, 5, 6],
        assigneeHint: 'Sarah',
      );
      final decoded = ChoreDefault.fromJson(chore.toJson());
      expect(decoded.title, 'Morning milking');
      expect(decoded.weekdays, [1, 2, 3, 4, 5, 6]);
      expect(decoded.assigneeHint, 'Sarah');
    });

    test('rejects weekdays outside 1-6 (Sunday rest)', () {
      expect(
        () => ChoreDefault.fromJson({
          'title': 'x',
          'weekdays': [7],
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ChoreDefault.fromJson({
          'title': 'x',
          'weekdays': [0],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('matches a weekday', () {
      const chore = ChoreDefault(title: 'x', weekdays: [1, 3, 5]);
      expect(chore.runsOnWeekday(DateTime(2026, 7, 31)), isTrue); // Friday
      expect(chore.runsOnWeekday(DateTime(2026, 8, 2)), isFalse); // Sunday
    });
  });

  group('RoleDefaultSet', () {
    const defaultSet = RoleDefaultSet(
      role: FarmRole.milkers,
      chores: [
        ChoreDefault(title: 'Morning milking', weekdays: [1, 2, 3, 4, 5, 6]),
        ChoreDefault(title: 'Clean stalls', weekdays: [1, 4]),
      ],
    );

    test('dTag is the role id', () {
      expect(defaultSet.dTag, 'milkers');
    });

    test('roundtrips through a signed Nostr event (kind 31500)', () {
      final event = defaultSet.toNostrEvent(
        pubKey: farmPubkey,
        createdAt: 1000,
        farmPubkey: farmPubkey,
      );
      expect(event.kind, 31500);
      expect(
        event.tags,
        containsAll([
          ['d', 'milkers'],
          ['farm', farmPubkey],
        ]),
      );
      final decoded = RoleDefaultSet.fromNostrEvent(event);
      expect(decoded.role, FarmRole.milkers);
      expect(decoded.chores.length, 2);
      expect(decoded.chores[0].title, 'Morning milking');
      expect(decoded.chores[1].weekdays, [1, 4]);
    });

    test('rejects events of other kinds', () {
      final event = NostrEvent(
        pubKey: farmPubkey,
        createdAt: 1000,
        kind: 31501,
        content: '{}',
      );
      expect(
        () => RoleDefaultSet.fromNostrEvent(event),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a malformed d tag when content has no role', () {
      final event = NostrEvent(
        pubKey: farmPubkey,
        createdAt: 1,
        kind: roleDefaultSetKind,
        content: '{"chores":[]}',
        tags: [
          ['d', 'not-a-role'],
        ],
      );
      expect(
        () => RoleDefaultSet.fromNostrEvent(event),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects malformed content JSON', () {
      final event = NostrEvent(
        pubKey: farmPubkey,
        createdAt: 1000,
        kind: 31500,
        content: 'not json',
        tags: [
          ['d', 'milkers'],
        ],
      );
      expect(
        () => RoleDefaultSet.fromNostrEvent(event),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
