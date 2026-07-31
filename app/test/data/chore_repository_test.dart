import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/role_default_set.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/nostr/nostr_event.dart';
import 'package:nostr/nostr.dart';

void main() {
  late AppDatabase db;
  late Keys keys;
  late ChoreRepository repo;
  final farmPubkey = 'f' * 64;
  final friday = DateTime(2026, 7, 31);

  setUp(() async {
    db = await AppDatabase.openInMemory();
    keys = Keys.generate();
    repo = ChoreRepository(database: db, keys: keys, farmPubkey: farmPubkey);
  });

  tearDown(() => db.close());

  const milkers = RoleDefaultSet(
    role: FarmRole.milkers,
    chores: [
      ChoreDefault(title: 'Morning milking', weekdays: [1, 2, 3, 4, 5, 6]),
      ChoreDefault(title: 'Clean stalls', weekdays: [1, 4]),
    ],
  );

  group('role default sets', () {
    test('save and load a default set', () async {
      await repo.saveRoleDefaultSet(milkers);
      final loaded = await repo.loadRoleDefaultSets();
      expect(loaded.single.role, FarmRole.milkers);
      expect(loaded.single.chores.length, 2);
    });

    test('latest event wins per role (LWW)', () async {
      await repo.saveRoleDefaultSet(milkers);
      await repo.saveRoleDefaultSet(
        const RoleDefaultSet(
          role: FarmRole.milkers,
          chores: [
            ChoreDefault(title: 'Milking AM', weekdays: [1, 2, 3, 4, 5, 6]),
          ],
        ),
      );
      final loaded = await repo.loadRoleDefaultSets();
      expect(loaded.single.chores.single.title, 'Milking AM');
    });
  });

  group('daily generation', () {
    test('generates only missing instances, once', () async {
      await repo.saveRoleDefaultSet(milkers);
      expect(await repo.ensureDayGenerated(friday), 1); // Fri => only milking
      expect(await repo.ensureDayGenerated(friday), 0); // idempotent
      final instances = await repo.loadInstancesForDate(friday);
      expect(instances.single.title, 'Morning milking');
    });

    test('stored events are signed and valid', () async {
      await repo.saveRoleDefaultSet(milkers);
      await repo.ensureDayGenerated(friday);
      final row = (await db.eventsForKind(31501).get()).single;
      expect(row.sig, hasLength(128));
      expect(row.pubkey, keys.public);
      expect(row.content, contains('Morning milking'));
      final signed = NostrEvent(
        id: row.id,
        pubKey: row.pubkey,
        createdAt: row.createdAt,
        kind: row.kind,
        content: row.content,
        sig: row.sig,
        tags: (jsonDecode(row.tags) as List)
            .map((t) => (t as List).cast<String>())
            .toList(),
      );
      expect(signed.verifySignature(), isTrue);
      expect(ChoreInstance.fromNostrEvent(signed).status, ChoreStatus.open);
    });
  });

  group('assignment and edits', () {
    test('assign persists the assignee and an assignment event', () async {
      await repo.saveRoleDefaultSet(milkers);
      await repo.ensureDayGenerated(friday);
      final instance = (await repo.loadInstancesForDate(friday)).single;
      final assignee = 'a' * 64;
      await repo.assign(instance, assignee);
      final updated = (await repo.loadInstancesForDate(friday)).single;
      expect(updated.assignee, assignee);
      final assignments = await db.eventsForKind(31502).get();
      expect(assignments, hasLength(1));
      expect(
        assignments.single.tags,
        contains('["e","2026-07-31|milkers|morning-milking"]'),
      );
      expect(assignments.single.tags, contains('["p","$assignee"]'));
    });

    test('editStatus flips the instance and logs an edit', () async {
      await repo.saveRoleDefaultSet(milkers);
      await repo.ensureDayGenerated(friday);
      final instance = (await repo.loadInstancesForDate(friday)).single;
      final done = await repo.editStatus(instance, ChoreStatus.done);
      expect(done.status, ChoreStatus.done);
      final reloaded = (await repo.loadInstancesForDate(friday)).single;
      expect(reloaded.status, ChoreStatus.done);
      final edits = await db.eventsForKind(31503).get();
      expect(edits, hasLength(1));
      expect(edits.single.content, contains('"status"'));
      expect(edits.single.content, contains('"one-time"'));
    });
  });
}
