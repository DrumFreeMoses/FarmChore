import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/data/app_database.dart';

void main() {
  group('AppDatabase schema v1', () {
    test('starts at schema version 1 and creates the events table', () async {
      final db = await AppDatabase.openInMemory();
      addTearDown(db.close);

      expect(db.schemaVersion, 1);
      final tables = await db.customSelect("SELECT name FROM sqlite_master WHERE type='table'").get();
      final names = tables.map((r) => r.data['name'] as String).toSet();
      expect(names, contains('events'));
    });

    test('inserts and queries an event by kind', () async {
      final db = await AppDatabase.openInMemory();
      addTearDown(db.close);

      await db.into(db.events).insert(EventsCompanion.insert(
            id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            pubkey:
                '6e468422dfb74a5738702a8823b9b28168abab8655faacb6853cd0ee15deee93',
            kind: 31501,
            createdAt: 1673342637,
            content: '{"title":"Morning milking"}',
            sig: Value('a1b2' * 32),
            tags: const Value('[["role","Milkers"]]'),
          ));

      final got = await db.eventsForKind(31501).getSingle();
      expect(got.id, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
      expect(got.kind, 31501);
    });

    test('rejects duplicate event ids', () async {
      final db = await AppDatabase.openInMemory();
      addTearDown(db.close);

      final row = EventsCompanion.insert(
        id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        pubkey:
            '6e468422dfb74a5738702a8823b9b28168abab8655faacb6853cd0ee15deee93',
        kind: 31500,
        createdAt: 1,
        content: '{}',
        sig: Value('a1b2' * 32),
        tags: const Value('[]'),
      );
      await db.into(db.events).insert(row);
      await expectLater(
        db.into(db.events).insert(row),
        throwsA(isA<Object>()),
      );
    });

    test('unsynced events are tracked for the outbound queue', () async {
      final db = await AppDatabase.openInMemory();
      addTearDown(db.close);

      await db.into(db.events).insert(EventsCompanion.insert(
            id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
            pubkey:
                '6e468422dfb74a5738702a8823b9b28168abab8655faacb6853cd0ee15deee93',
            kind: 31502,
            createdAt: 2,
            content: '',
            sig: Value('a1b2' * 32),
            tags: const Value('[]'),
          ));

      final queued = await db.pendingEvents().get();
      expect(queued.length, 1);
      expect(queued.single.sent, isFalse);
    });
  });
}
