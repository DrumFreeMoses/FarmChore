import 'dart:async';

import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/nostr/nostr_event.dart';
import 'package:farm_chore/sync/relay_connection.dart';
import 'package:farm_chore/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr/nostr.dart';

void main() {
  late AppDatabase db;
  late Keys keys;
  late ChoreRepository repo;
  final farmPubkey = 'f' * 64;

  setUp(() async {
    db = await AppDatabase.openInMemory();
    keys = Keys.generate();
    repo = ChoreRepository(database: db, keys: keys, farmPubkey: farmPubkey);
  });

  tearDown(() => db.close());

  group('SyncService', () {
    test('pushes pending events and marks them sent', () async {
      final instance = ChoreInstance(
        date: DateTime(2026, 7, 31),
        role: FarmRole.milkers,
        slug: 'milking-am',
        title: 'Morning milking',
        type: ChoreType.chore,
        status: ChoreStatus.open,
      );
      await repo.saveInstance(instance);

      final pendingBefore = await repo.pendingEvents();
      expect(pendingBefore.length, 1); // verify only 1 event queued

      final fake = FakeRelay();
      final sync = SyncService(repository: repo, connectionFactory: () => fake);
      final result = await sync.sync();

      expect(result.pushed, 1);
      final eventsSent = fake.sent.where((m) => m.first == 'EVENT').length;
      expect(eventsSent, 1);
      expect(fake.sent.first.first, 'EVENT');
      final payload = fake.sent.first[1] as Map;
      expect(payload['kind'], 31501);
      expect(payload['content'], contains('Morning milking'));

      final pending = await repo.pendingEvents();
      expect(pending, isEmpty);
    });

    test('duplicate rejection marks event sent without retry', () async {
      final instance = ChoreInstance(
        date: DateTime(2026, 7, 31),
        role: FarmRole.milkers,
        slug: 'milking-am',
        title: 'Morning milking',
        type: ChoreType.chore,
        status: ChoreStatus.open,
      );
      await repo.saveInstance(instance);

      final fake = FakeRelay(accept: false, reason: 'duplicate');
      final sync = SyncService(repository: repo, connectionFactory: () => fake);
      final result = await sync.sync();

      expect(result.pushed, 0);
      final pending = await repo.pendingEvents();
      expect(pending, isEmpty);
    });

    test('other rejection leaves event pending for retry', () async {
      final instance = ChoreInstance(
        date: DateTime(2026, 7, 31),
        role: FarmRole.milkers,
        slug: 'milking-am',
        title: 'Morning milking',
        type: ChoreType.chore,
        status: ChoreStatus.open,
      );
      await repo.saveInstance(instance);

      final fake = FakeRelay(accept: false, reason: 'invalid: bad sig');
      final sync = SyncService(repository: repo, connectionFactory: () => fake);
      final result = await sync.sync();

      expect(result.pushed, 0);
      final pending = await repo.pendingEvents();
      expect(pending.length, 1);
    });

    test('pulls remote events and imports them', () async {
      final remote = _signedEvent(
        kind: 31501,
        content: '{"title":"Remote milking","status":"open","type":"chore"}',
        tags: [
          ['d', '2026-07-31|milkers|milking-am'],
          ['role', 'milkers'],
          ['date', '2026-07-31'],
        ],
      );

      final fake = FakeRelay(remote: [remote]);
      final sync = SyncService(repository: repo, connectionFactory: () => fake);
      final result = await sync.sync();

      expect(result.pulled, 1);
      final instances = await repo.loadInstancesForDate(DateTime(2026, 7, 31));
      expect(instances.length, 1);
      expect(instances.single.title, 'Remote milking');
    });

    test('rejects tampered events (bad signature)', () async {
      final remote = _signedEvent(
        kind: 31501,
        content: '{"title":"Remote milking","status":"open","type":"chore"}',
        tags: [
          ['d', '2026-07-31|milkers|milking-am'],
          ['role', 'milkers'],
          ['date', '2026-07-31'],
        ],
      );
      // Tamper: change content but keep old id/sig → verification fails.
      final tampered = {...remote, 'content': '{"title":"HACKED"}'};

      final fake = FakeRelay(remote: [tampered]);
      final sync = SyncService(repository: repo, connectionFactory: () => fake);
      final result = await sync.sync();

      expect(result.pulled, 0);
      final instances = await repo.loadInstancesForDate(DateTime(2026, 7, 31));
      expect(instances, isEmpty);
    });

    test('rejects events with unknown kinds', () async {
      final remote = _signedEvent(
        kind: 9999,
        content: '{}',
        tags: [
          ['d', 'foo'],
        ],
      );

      final fake = FakeRelay(remote: [remote]);
      final sync = SyncService(repository: repo, connectionFactory: () => fake);
      final result = await sync.sync();

      expect(result.pulled, 0);
    });

    test('offline returns gracefully, queue intact', () async {
      final instance = ChoreInstance(
        date: DateTime(2026, 7, 31),
        role: FarmRole.milkers,
        slug: 'milking-am',
        title: 'Morning milking',
        type: ChoreType.chore,
        status: ChoreStatus.open,
      );
      await repo.saveInstance(instance);

      final fake = FakeRelay(failConnect: true);
      final sync = SyncService(repository: repo, connectionFactory: () => fake);
      final result = await sync.sync();

      expect(result.pushed, 0);
      expect(result.pulled, 0);
      final pending = await repo.pendingEvents();
      expect(pending.length, 1);
    });

    test('LWW: newer event per d-tag wins at read time', () async {
      // Older event (same d-tag, older createdAt)
      final older = _signedEvent(
        kind: 31501,
        createdAt: 1700000000,
        content: '{"title":"Old","status":"open","type":"chore"}',
        tags: [
          ['d', '2026-07-31|milkers|milking-am'],
          ['role', 'milkers'],
          ['date', '2026-07-31'],
        ],
      );
      // Newer event (same d-tag, newer createdAt)
      final newer = _signedEvent(
        kind: 31501,
        createdAt: 1700000001,
        content: '{"title":"New","status":"open","type":"chore"}',
        tags: [
          ['d', '2026-07-31|milkers|milking-am'],
          ['role', 'milkers'],
          ['date', '2026-07-31'],
        ],
      );

      final fake = FakeRelay(remote: [older, newer]);
      final sync = SyncService(repository: repo, connectionFactory: () => fake);
      final result = await sync.sync();

      expect(result.pulled, 2);
      final instances = await repo.loadInstancesForDate(DateTime(2026, 7, 31));
      expect(instances.length, 1);
      expect(instances.single.title, 'New');
    });
  });

  group('SyncService live subscription', () {
    test('receives pushed events and fires onRemoteEvents', () async {
      final remote = _signedEvent(
        kind: 31501,
        content: '{"title":"Remote milking","status":"open","type":"chore"}',
        tags: [
          ['d', '2026-07-31|milkers|milking-am'],
          ['role', 'milkers'],
          ['date', '2026-07-31'],
        ],
      );

      final fake = FakeRelay();
      final sync = SyncService(repository: repo, connectionFactory: () => fake);

      final events = <void>[];
      sync.onRemoteEvents.listen((_) => events.add(null));

      sync.startLiveSubscription();
      // Wait for the connection to establish and REQ to be sent.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Relay pushes an event.
      fake.pushEvent(remote);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events, hasLength(1));
      final instances = await repo.loadInstancesForDate(DateTime(2026, 7, 31));
      expect(instances.length, 1);
      expect(instances.single.title, 'Remote milking');

      await sync.stopLiveSubscription();
    });

    test('isLive reports connection state', () async {
      final fake = FakeRelay();
      final sync = SyncService(repository: repo, connectionFactory: () => fake);

      expect(sync.isLive, isFalse);
      sync.startLiveSubscription();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sync.isLive, isTrue);
      await sync.stopLiveSubscription();
      expect(sync.isLive, isFalse);
    });

    test('stopLiveSubscription cleans up resources', () async {
      final fake = FakeRelay();
      final sync = SyncService(repository: repo, connectionFactory: () => fake);

      sync.startLiveSubscription();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sync.stopLiveSubscription();

      // After stop, pushing events should not crash.
      fake.pushEvent(
        _signedEvent(
          kind: 31501,
          content: '{}',
          tags: [
            ['d', 'test'],
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // No crash = pass.
    });
  });
}

Map<String, Object?> _signedEvent({
  required int kind,
  required String content,
  required List<List<String>> tags,
  int createdAt = 1700000000,
}) {
  final keys = Keys.generate();
  final event = NostrEvent(
    pubKey: keys.public,
    createdAt: createdAt,
    kind: kind,
    tags: tags,
    content: content,
  ).signed(keys);
  return {
    'id': event.id,
    'pubkey': event.pubKey,
    'created_at': event.createdAt,
    'kind': event.kind,
    'tags': event.tags,
    'content': event.content,
    'sig': event.sig,
  };
}

class FakeRelay implements RelayConnection {
  FakeRelay({
    this.accept = true,
    this.reason = '',
    this.failConnect = false,
    List<Map<String, Object?>>? remote,
  }) : remoteEvents = remote ?? [];

  final bool accept;
  final String reason;
  final bool failConnect;
  final List<Map<String, Object?>> remoteEvents;
  final List<List<Object?>> sent = [];
  final StreamController<List<Object?>> _incoming =
      StreamController.broadcast();

  @override
  Future<void> connect() async {
    if (failConnect) {
      throw Exception('offline');
    }
  }

  @override
  Future<void> send(List<Object?> message) async {
    sent.add(message);
    final verb = message.first;
    if (verb == 'EVENT') {
      final payload = message[1] as Map;
      final id = payload['id'];
      _incoming.add(['OK', id, accept, reason]);
    } else if (verb == 'REQ') {
      for (final event in remoteEvents) {
        _incoming.add(['EVENT', message[1], event]);
      }
      _incoming.add(['EOSE', message[1]]);
    }
  }

  /// Push an event from the relay side (simulates another device publishing).
  void pushEvent(Map<String, Object?> event) {
    _incoming.add(['EVENT', 'live-sub', event]);
  }

  @override
  Stream<List<Object?>> receive() => _incoming.stream;

  @override
  Future<void> close() async {}
}
