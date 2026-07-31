import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/identity/identity_service.dart';
import 'package:farm_chore/identity/key_storage.dart';
import 'package:nostr/nostr.dart';

void main() {
  group('IdentityService', () {
    test('generates a fresh identity on first run and persists it', () async {
      final storage = InMemoryKeyStorage();
      final service = IdentityService(storage);

      final first = await service.ensureIdentity();
      expect(first.pubkey, isNotEmpty);
      expect(first.npub, startsWith('npub1'));
      expect(first.nsec, startsWith('nsec1'));

      final second = await service.ensureIdentity();
      expect(second.pubkey, first.pubkey);
      expect(storage.savedCount, 1, reason: 'identity must not be regenerated');
    });

    test('imports an identity from nsec and from hex secret', () async {
      final keys = Keys.generate();
      final storage = InMemoryKeyStorage();
      final service = IdentityService(storage);

      final fromNsec = await service.importIdentity(keys.nsec);
      expect(fromNsec.pubkey, keys.public);

      final fromHex = await service.importIdentity(keys.secret);
      expect(fromHex.pubkey, keys.public);
    });

    test('rejects malformed secrets', () async {
      final service = IdentityService(InMemoryKeyStorage());
      expect(() => service.importIdentity('not-a-secret'), throwsArgumentError);
      expect(() => service.importIdentity('a' * 63), throwsArgumentError);
    });
  });
}
