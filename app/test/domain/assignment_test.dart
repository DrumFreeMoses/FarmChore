import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/domain/assignment.dart';
import 'package:farm_chore/nostr/nostr_event.dart';

void main() {
  final farmPubkey = 'f' * 64;
  final assignee = 'b' * 64;
  final assignor = 'c' * 64;
  const instanceId = 'abc123';

  group('Assignment', () {
    test('roundtrips through a signed Nostr event (kind 31502)', () {
      final assignment = Assignment(instanceId: instanceId, assignee: assignee);
      final event = assignment.toNostrEvent(
        pubKey: assignor,
        createdAt: 1000,
        farmPubkey: farmPubkey,
      );
      expect(event.kind, 31502);
      expect(event.tags, [
        ['e', instanceId],
        ['p', assignee],
        ['farm', farmPubkey],
      ]);
      final decoded = Assignment.fromNostrEvent(event);
      expect(decoded.instanceId, instanceId);
      expect(decoded.assignee, assignee);
    });

    test('is self-assignment when the signer is the assignee', () {
      final assignment = Assignment(instanceId: instanceId, assignee: assignee);
      final event = assignment.toNostrEvent(pubKey: assignee, createdAt: 1000);
      expect(Assignment.fromNostrEvent(event).isSelfAssign(assignee), isTrue);
      expect(Assignment.fromNostrEvent(event).isSelfAssign(assignor), isFalse);
    });

    test('rejects events of other kinds', () {
      final event = NostrEvent(pubKey: assignor, createdAt: 1, kind: 31501);
      expect(
        () => Assignment.fromNostrEvent(event),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an assignment without an instance id', () {
      final event = NostrEvent(
        pubKey: assignor,
        createdAt: 1,
        kind: 31502,
        tags: [
          ['p', assignee],
        ],
      );
      expect(
        () => Assignment.fromNostrEvent(event),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an assignment without an assignee', () {
      final event = NostrEvent(
        pubKey: assignor,
        createdAt: 1,
        kind: 31502,
        tags: [
          ['e', instanceId],
        ],
      );
      expect(
        () => Assignment.fromNostrEvent(event),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
