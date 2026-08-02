import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
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

  group('Integration: daily generation flow', () {
    test('seed generate load roundtrip', () async {
      const defaults = RoleDefaultSet(
        role: FarmRole.milkers,
        chores: [
          ChoreDefault(
            title: 'Morning milking',
            weekdays: [1, 2, 3, 4, 5, 6],
          ),
          ChoreDefault(
            title: 'Evening milking',
            weekdays: [1, 2, 3, 4, 5, 6],
          ),
        ],
      );
      await repo.saveRoleDefaultSet(defaults);

      final today = DateTime(2026, 8, 3); // Monday
      final generated = await repo.ensureDayGenerated(today);
      final loaded = await repo.loadInstancesForDate(today);

      expect(generated, 2);
      expect(loaded.length, 2);
      expect(loaded[0].role, FarmRole.milkers);
    });
  });

  group('Integration: assignment and status flow', () {
    test('assign then editStatus done', () async {
      final instance = ChoreInstance(
        date: DateTime(2026, 8, 3),
        role: FarmRole.milkers,
        slug: 'milking-am',
        title: 'Morning milking',
        type: ChoreType.chore,
        status: ChoreStatus.open,
      );
      await repo.saveInstance(instance);

      await repo.assign(instance, keys.public);
      final assigned = await repo.loadInstancesForDate(DateTime(2026, 8, 3));
      expect(assigned.single.assignee, keys.public);

      await repo.editStatus(assigned.single, ChoreStatus.done);
      final done = await repo.loadInstancesForDate(DateTime(2026, 8, 3));
      expect(done.single.status, ChoreStatus.done);
    });

    test('skip and defer flow', () async {
      final instance = ChoreInstance(
        date: DateTime(2026, 8, 3),
        role: FarmRole.feeders,
        slug: 'feed-am',
        title: 'Morning feed',
        type: ChoreType.chore,
        status: ChoreStatus.open,
      );
      await repo.saveInstance(instance);

      await repo.editStatus(instance, ChoreStatus.skipped);
      final skipped = await repo.loadInstancesForDate(DateTime(2026, 8, 3));
      expect(skipped.single.status, ChoreStatus.skipped);

      final deferred = instance.copyWith(
        status: ChoreStatus.deferred,
        deferredTo: DateTime(2026, 8, 4),
      );
      await repo.saveInstance(deferred);
      final deferredInstances = await repo.loadInstancesForDate(
        DateTime(2026, 8, 3),
      );
      expect(deferredInstances.single.status, ChoreStatus.deferred);
      expect(deferredInstances.single.deferredTo, DateTime(2026, 8, 4));
    });
  });

  group('Integration: messaging flow', () {
    test('broadcast and DM flow', () async {
      await repo.sendMessage('Good morning farm!');
      await repo.sendMessage('Hey, can you cover my shift?',
          recipient: 'key456');

      final messages = await repo.loadMessages();
      expect(messages.length, 2);

      final broadcast = messages.where((m) => m.isBroadcast).first;
      expect(broadcast.text, 'Good morning farm!');
      expect(broadcast.author, keys.public);

      final dm = messages.where((m) => m.isDirect).first;
      expect(dm.text, 'Hey, can you cover my shift?');
      expect(dm.recipient, 'key456');
    });

    test('conversation grouping', () async {
      await repo.sendMessage('Farm-wide update');
      await repo.sendMessage('DM to Alice', recipient: 'alice');
      await repo.sendMessage('DM to Bob', recipient: 'bob');
      await repo.sendMessage('Another DM to Alice', recipient: 'alice');

      final messages = await repo.loadMessages();

      final farmConvo = messages
          .where((m) => m.conversationWith(keys.public) == 'farm')
          .toList();
      final aliceConvo = messages
          .where((m) => m.conversationWith(keys.public) == 'alice')
          .toList();
      final bobConvo = messages
          .where((m) => m.conversationWith(keys.public) == 'bob')
          .toList();

      expect(farmConvo.length, 1);
      expect(aliceConvo.length, 2);
      expect(bobConvo.length, 1);
    });
  });

  group('Integration: heads-up flow', () {
    test('post and load heads-up', () async {
      await repo.saveHeadsUp('Frost tonight - cover the greens');
      await repo.saveHeadsUp('Tractor needs gas', scope: FarmRole.mechanics);

      final headsUps = await repo.loadHeadsUps();
      expect(headsUps.length, 2);

      final farmWide = headsUps.where((h) => h.isFarmWide).first;
      expect(farmWide.text, 'Frost tonight - cover the greens');

      final roleScoped = headsUps.where((h) => !h.isFarmWide).first;
      expect(roleScoped.scope, FarmRole.mechanics);
    });
  });

  group('Integration: member profile flow', () {
    test('save and load profile', () async {
      await repo.saveMyName('Moses');
      final names = await repo.loadMemberNames();
      expect(names[keys.public], 'Moses');
    });

    test('load all members', () async {
      await repo.saveMyName('Moses');
      final members = await repo.loadAllMembers();
      expect(members.length, 1);
      expect(members.first.name, 'Moses');
    });
  });
}
