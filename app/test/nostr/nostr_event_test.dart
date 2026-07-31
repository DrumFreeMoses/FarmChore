import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/nostr/nostr_event.dart';

void main() {
  group('NostrEvent canonical id', () {
    test('matches the NIP-01 canonical serialization (spec vector)', () {
      final event = NostrEvent(
        pubKey:
            '6e468422dfb74a5738702a8823b9b28168abab8655faacb6853cd0ee15deee93',
        createdAt: 1673342637,
        kind: 1,
        tags: [
          [
            'e',
            '3da979448d9ba263864c4d6f14997c079ba216ffa52b32a6ad98c8e6cdd3c1e6',
          ],
        ],
        content: 'Hello world',
      );
      // Computed with the same rules as the relay (compact JSON, no spaces).
      expect(
        event.computedId,
        'ba5cc5dc9b37809db7ad666da2826926641a24e5734327a245b43c5fe862e61f',
      );
    });

    test('id changes when content changes', () {
      final a = NostrEvent(
        pubKey:
            '6e468422dfb74a5738702a8823b9b28168abab8655faacb6853cd0ee15deee93',
        createdAt: 1673342637,
        kind: 31501,
        content: 'feed the pigs',
      );
      final b = a.copyWith(content: 'feed the pigs NOW');
      expect(a.computedId, isNot(b.computedId));
    });

    test('serializes tags compactly (no spaces)', () {
      final event = NostrEvent(
        pubKey:
            '6e468422dfb74a5738702a8823b9b28168abab8655faacb6853cd0ee15deee93',
        createdAt: 1,
        kind: 31500,
        tags: [
          ['role', 'Milkers'],
        ],
        content: '{}',
      );
      expect(
        event.canonicalSerialization(),
        '[0,"6e468422dfb74a5738702a8823b9b28168abab8655faacb6853cd0ee15deee93",1,31500,[["role","Milkers"]],"{}"]',
      );
    });
  });
}
