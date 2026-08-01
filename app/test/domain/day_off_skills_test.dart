import 'package:farm_chore/domain/daily_generator.dart';
import 'package:farm_chore/domain/member_profile.dart';
import 'package:farm_chore/domain/role_default_set.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final friday = DateTime(2026, 7, 31); // Friday, weekday 5
  final monday = DateTime(2026, 8, 3); // Monday, weekday 1

  group('DailyGenerator with members', () {
    test('skips assignee on their day off', () {
      const defaults = RoleDefaultSet(
        role: FarmRole.milkers,
        chores: [
          ChoreDefault(
            title: 'Morning milking',
            weekdays: [1, 2, 3, 4, 5, 6],
            assigneeHint: 'pubkey1',
          ),
        ],
      );
      final members = [
        MemberProfile(
          pubkey: 'pubkey1',
          name: 'Moses',
          dayOff: 5, // Friday
        ),
      ];

      final instances = DailyGenerator.generate(
        defaults: [defaults],
        date: friday,
        members: members,
      );

      expect(instances.single.assignee, isNull);
    });

    test('assigns when member is available and has skills', () {
      const defaults = RoleDefaultSet(
        role: FarmRole.milkers,
        chores: [
          ChoreDefault(
            title: 'Morning milking',
            weekdays: [1, 2, 3, 4, 5, 6],
            assigneeHint: 'pubkey1',
            requiredSkills: ['milker'],
          ),
        ],
      );
      final members = [
        MemberProfile(pubkey: 'pubkey1', name: 'Moses', skills: ['milker']),
      ];

      final instances = DailyGenerator.generate(
        defaults: [defaults],
        date: friday,
        members: members,
      );

      expect(instances.single.assignee, 'pubkey1');
    });

    test('skips assignee without required skills', () {
      const defaults = RoleDefaultSet(
        role: FarmRole.milkers,
        chores: [
          ChoreDefault(
            title: 'Morning milking',
            weekdays: [1, 2, 3, 4, 5, 6],
            assigneeHint: 'pubkey1',
            requiredSkills: ['milker'],
          ),
        ],
      );
      final members = [
        MemberProfile(
          pubkey: 'pubkey1',
          name: 'Moses',
          skills: [], // no skills
        ),
      ];

      final instances = DailyGenerator.generate(
        defaults: [defaults],
        date: friday,
        members: members,
      );

      expect(instances.single.assignee, isNull);
    });

    test('assigns to different member on different day off', () {
      const defaults = RoleDefaultSet(
        role: FarmRole.milkers,
        chores: [
          ChoreDefault(
            title: 'Morning milking',
            weekdays: [1, 2, 3, 4, 5, 6],
            assigneeHint: 'pubkey1',
          ),
        ],
      );
      final members = [
        MemberProfile(
          pubkey: 'pubkey1',
          name: 'Moses',
          dayOff: 5, // Friday
        ),
      ];

      // Monday (weekday 1) — not Moses' day off
      final instances = DailyGenerator.generate(
        defaults: [defaults],
        date: monday,
        members: members,
      );

      expect(instances.single.assignee, 'pubkey1');
    });

    test('no members list carries hint as-is (backward compatible)', () {
      const defaults = RoleDefaultSet(
        role: FarmRole.milkers,
        chores: [
          ChoreDefault(
            title: 'Morning milking',
            weekdays: [1, 2, 3, 4, 5, 6],
            assigneeHint: 'pubkey1',
          ),
        ],
      );

      final instances = DailyGenerator.generate(
        defaults: [defaults],
        date: friday,
      );

      expect(instances.single.assignee, 'pubkey1');
    });
  });

  group('MemberProfile skills and day off', () {
    test('hasSkills returns true when member has all required skills', () {
      const member = MemberProfile(
        pubkey: 'key',
        name: 'Moses',
        skills: ['milker', 'skid-loader'],
      );

      expect(member.hasSkills(['milker']), isTrue);
      expect(member.hasSkills(['milker', 'skid-loader']), isTrue);
      expect(member.hasSkills(['tractor']), isFalse);
      expect(member.hasSkills([]), isTrue);
    });

    test('isOffOn returns true for the member day off', () {
      const member = MemberProfile(
        pubkey: 'key',
        name: 'Moses',
        dayOff: 5, // Friday
      );

      expect(member.isOffOn(5), isTrue);
      expect(member.isOffOn(1), isFalse);
    });

    test('copyWith preserves fields', () {
      const member = MemberProfile(
        pubkey: 'key',
        name: 'Moses',
        dayOff: 5,
        skills: ['milker'],
      );

      final updated = member.copyWith(name: 'Moses Jr.');
      expect(updated.name, 'Moses Jr.');
      expect(updated.dayOff, 5);
      expect(updated.skills, ['milker']);
    });

    test('copyWith clearDayOff removes day off', () {
      const member = MemberProfile(pubkey: 'key', name: 'Moses', dayOff: 5);

      final updated = member.copyWith(clearDayOff: true);
      expect(updated.dayOff, isNull);
    });

    test('roundtrips through Nostr event', () {
      const member = MemberProfile(
        pubkey: 'key123',
        name: 'Moses',
        dayOff: 5,
        skills: ['milker', 'skid-loader'],
      );

      final event = member.toNostrEvent(
        pubKey: 'key123',
        createdAt: 1700000000,
      );
      final parsed = MemberProfile.fromNostrEvent(event);

      expect(parsed.pubkey, 'key123');
      expect(parsed.name, 'Moses');
      expect(parsed.dayOff, 5);
      expect(parsed.skills, ['milker', 'skid-loader']);
    });

    test('backward compatible: old events without dayOff/skills', () {
      // Simulate an old event without dayOff or skills fields
      final event = MemberProfile(
        pubkey: 'key123',
        name: 'Moses',
      ).toNostrEvent(pubKey: 'key123', createdAt: 1700000000);

      final parsed = MemberProfile.fromNostrEvent(event);
      expect(parsed.dayOff, isNull);
      expect(parsed.skills, isEmpty);
    });
  });

  group('ChoreDefault requiredSkills', () {
    test('roundtrips through JSON', () {
      const chore = ChoreDefault(
        title: 'Morning milking',
        weekdays: [1, 2, 3, 4, 5, 6],
        assigneeHint: 'pubkey1',
        requiredSkills: ['milker'],
      );

      final json = chore.toJson();
      final parsed = ChoreDefault.fromJson(json);

      expect(parsed.title, 'Morning milking');
      expect(parsed.requiredSkills, ['milker']);
    });

    test('backward compatible: old defaults without requiredSkills', () {
      final json = {
        'title': 'Morning milking',
        'weekdays': [1, 2, 3, 4, 5, 6],
      };

      final parsed = ChoreDefault.fromJson(json);
      expect(parsed.requiredSkills, isEmpty);
    });
  });
}
