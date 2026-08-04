import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_comment.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/role_default_set.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr/nostr.dart';

void main() {
  late AppDatabase db;
  late Keys keys;
  late ChoreRepository repo;

  setUp(() async {
    db = await AppDatabase.openInMemory();
    keys = Keys.generate();
    repo = ChoreRepository(database: db, keys: keys);
  });

  tearDown(() => db.close());

  group('ChoreDefault description and checklist', () {
    test('serializes and deserializes with description and checklist', () {
      const chore = ChoreDefault(
        title: 'Morning milking',
        weekdays: [1, 2, 3, 4, 5, 6],
        description: 'Connect the milking equipment and sanitize teats.',
        checklist: ['Check equipment', 'Sanitize', 'Attach cups'],
      );

      final json = chore.toJson();
      final parsed = ChoreDefault.fromJson(json);

      expect(
        parsed.description,
        'Connect the milking equipment and sanitize teats.',
      );
      expect(parsed.checklist, ['Check equipment', 'Sanitize', 'Attach cups']);
    });

    test('backward compatible without description and checklist', () {
      final json = {
        'title': 'Morning milking',
        'weekdays': [1, 2, 3, 4, 5, 6],
      };

      final parsed = ChoreDefault.fromJson(json);
      expect(parsed.description, '');
      expect(parsed.checklist, isEmpty);
    });
  });

  group('ChoreComment', () {
    test('roundtrips through Nostr event', () {
      const comment = ChoreComment(
        text: 'Need to order more teat dip',
        author: 'key123',
        createdAt: 1700000000,
        instanceDTag: '2026-08-03|milkers|milking-am',
      );

      final event = comment.toNostrEvent(
        pubKey: 'key123',
        createdAt: 1700000000,
      );
      final parsed = ChoreComment.fromNostrEvent(event);

      expect(parsed.text, 'Need to order more teat dip');
      expect(parsed.author, 'key123');
      expect(parsed.instanceDTag, '2026-08-03|milkers|milking-am');
    });
  });

  group('ChoreRepository comments', () {
    test('addComment and loadComments', () async {
      final instance = ChoreInstance(
        date: DateTime(2026, 8, 3),
        role: FarmRole.milkers,
        slug: 'milking-am',
        title: 'Morning milking',
        type: ChoreType.chore,
        status: ChoreStatus.open,
      );
      await repo.saveInstance(instance);

      await repo.addComment(instance.dTag, 'First comment');
      await repo.addComment(instance.dTag, 'Second comment');

      final comments = await repo.loadComments(instance.dTag);
      expect(comments.length, 2);
      expect(comments.first.text, 'Second comment');
      expect(comments.last.text, 'First comment');
    });
  });

  group('ChoreRepository chore sets', () {
    test('saveChoreSet and loadChoreSets', () async {
      const base = RoleDefaultSet(
        role: FarmRole.milkers,
        chores: [
          ChoreDefault(title: 'Morning milking', weekdays: [1, 2, 3, 4, 5, 6]),
        ],
      );
      await repo.saveRoleDefaultSet(base);

      await repo.saveChoreSet(FarmRole.milkers, 'Rainy day', const [
        ChoreDefault(title: 'Indoor cleaning', weekdays: [1, 2, 3, 4, 5, 6]),
      ]);

      final sets = await repo.loadChoreSets(FarmRole.milkers);
      expect(sets.length, 1);
      expect(sets.first.name, 'Rainy day');
    });

    test('activateChoreSet replaces base', () async {
      const base = RoleDefaultSet(
        role: FarmRole.milkers,
        chores: [
          ChoreDefault(title: 'Morning milking', weekdays: [1, 2, 3, 4, 5, 6]),
        ],
      );
      await repo.saveRoleDefaultSet(base);

      const variant = RoleDefaultSet(
        role: FarmRole.milkers,
        name: 'Holiday',
        chores: [
          ChoreDefault(title: 'Light duty', weekdays: [1, 2, 3, 4, 5, 6]),
        ],
      );
      await repo.saveRoleDefaultSet(variant);

      await repo.activateChoreSet(variant);

      final allBases = await repo.loadBaseRoleDefaultSets();
      final activeSet = allBases.firstWhere((s) => s.role == FarmRole.milkers);
      expect(activeSet.chores.first.title, 'Light duty');
    });

    test('deleteChoreSet removes variant', () async {
      const variant = RoleDefaultSet(
        role: FarmRole.milkers,
        name: 'Old set',
        chores: [
          ChoreDefault(title: 'Old chore', weekdays: [1, 2, 3, 4, 5, 6]),
        ],
      );
      await repo.saveRoleDefaultSet(variant);

      var sets = await repo.loadChoreSets(FarmRole.milkers);
      expect(sets.length, 1);

      await repo.deleteChoreSet(variant);

      sets = await repo.loadChoreSets(FarmRole.milkers);
      expect(sets.length, 0);
    });
  });
}
