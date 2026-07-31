import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/domain/edit_event.dart';
import 'package:farm_chore/nostr/nostr_event.dart';

void main() {
  final farmPubkey = 'f' * 64;
  final member = 'b' * 64;
  const instanceId = '2026-07-31|milkers|morning-milking';

  group('EditEvent', () {
    test('roundtrips through a signed Nostr event (kind 31503)', () {
      const edit = EditEvent(
        instanceId: instanceId,
        field: 'status',
        value: 'done',
      );
      final event = edit.toNostrEvent(
        pubKey: member,
        createdAt: 1000,
        farmPubkey: farmPubkey,
      );
      expect(event.kind, 31503);
      expect(event.tags, [
        ['e', instanceId],
        ['d', instanceId],
        ['farm', farmPubkey],
      ]);
      expect(
        event.content,
        '{"field":"status","value":"done","scope":"one-time"}',
      );
      final decoded = EditEvent.fromNostrEvent(event);
      expect(decoded.instanceId, instanceId);
      expect(decoded.field, 'status');
      expect(decoded.value, 'done');
      expect(decoded.scope, EditScope.oneTime);
    });

    test('a default-scope edit marks the role default as well', () {
      const edit = EditEvent(
        instanceId: instanceId,
        field: 'title',
        value: 'Milking AM',
        scope: EditScope.default_,
      );
      final event = edit.toNostrEvent(pubKey: member, createdAt: 1);
      expect(
        event.content,
        '{"field":"title","value":"Milking AM","scope":"default"}',
      );
      expect(EditEvent.fromNostrEvent(event).scope, EditScope.default_);
    });

    test('rejects events of other kinds', () {
      final event = NostrEvent(pubKey: member, createdAt: 1, kind: 31502);
      expect(
        () => EditEvent.fromNostrEvent(event),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an edit without an e tag', () {
      final event = NostrEvent(
        pubKey: member,
        createdAt: 1,
        kind: 31503,
        content: '{"field":"status","value":"done","scope":"one-time"}',
      );
      expect(
        () => EditEvent.fromNostrEvent(event),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
