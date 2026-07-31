import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/nostr/nostr_event.dart';
import 'package:nostr/nostr.dart';

void main() {
  group('event signing and verification', () {
    test('a generated key signs an event and the signature verifies', () {
      final keys = Keys.generate();
      final event = NostrEvent(
        pubKey: keys.public,
        createdAt: 1700000000,
        kind: 31501,
        tags: [
          ['role', 'Milkers'],
        ],
        content: '{"title":"Morning milking","status":"open"}',
      );

      final signed = event.signed(keys);

      expect(signed.id, isNotNull);
      expect(signed.id, event.computedId);
      expect(signed.sig, isNotNull);
      expect(signed.sig!.length, 128);
      expect(signed.verifySignature(), isTrue);
      expect(signed.pubKey, keys.public);
    });

    test('tampering with content or tags breaks verification', () {
      final keys = Keys.generate();
      final event = NostrEvent(
        pubKey: keys.public,
        createdAt: 1700000000,
        kind: 31501,
        content: 'original',
      ).signed(keys);

      final tamperedContent = event.copyWith(content: 'tampered');
      expect(tamperedContent.verifySignature(), isFalse);

      final tamperedTags = event.copyWith(
        tags: [
          ['role', 'Feeders'],
        ],
      );
      expect(tamperedTags.verifySignature(), isFalse);
    });

    test('a signature from a different key fails verification', () {
      final signer = Keys.generate();
      final other = Keys.generate();
      final event = NostrEvent(
        pubKey: signer.public,
        createdAt: 1700000000,
        kind: 31501,
        content: 'hello',
      ).signed(signer);

      final forged = NostrEvent(
        id: event.id,
        pubKey: other.public,
        createdAt: event.createdAt,
        kind: event.kind,
        content: event.content,
        sig: event.sig,
      );
      expect(forged.verifySignature(), isFalse);
    });

    test('canonical id interoperates with the nostr package event', () {
      final keys = Keys.generate();
      final ours = NostrEvent(
        pubKey: keys.public,
        createdAt: 1700000000,
        kind: 31501,
        tags: [
          ['role', 'Milkers'],
        ],
        content: '{"a":1}',
      );

      final theirs = Event.unsigned(
        pubkey: keys.public,
        createdAt: 1700000000,
        kind: 31501,
        tags: [
          ['role', 'Milkers'],
        ],
        content: '{"a":1}',
      );
      expect(ours.computedId, theirs.getEventId());
    });
  });
}
