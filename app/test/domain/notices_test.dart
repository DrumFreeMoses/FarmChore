import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/domain/heads_up.dart';
import 'package:farm_chore/domain/member_profile.dart';
import 'package:farm_chore/domain/roles.dart';

void main() {
  group('MemberProfile', () {
    test('round-trips name and pubkey', () {
      final profile = MemberProfile(pubkey: 'p' * 64, name: 'Moses');
      final event = profile.toNostrEvent(pubKey: 'p' * 64, createdAt: 1000);
      final decoded = MemberProfile.fromNostrEvent(event);
      expect(decoded.pubkey, 'p' * 64);
      expect(decoded.name, 'Moses');
      expect(decoded.dTag, 'p' * 64);
    });

    test('rejects an empty name', () {
      final event = const MemberProfile(
        pubkey: 'p',
        name: 'Moses',
      ).toNostrEvent(pubKey: 'p', createdAt: 1);
      final bad = event.copyWith(content: '{"name":""}');
      expect(
        () => MemberProfile.fromNostrEvent(bad),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('HeadsUp', () {
    test('round-trips a farm-wide notice', () {
      final notice = HeadsUp(
        text: 'Frost tonight',
        author: 'a' * 64,
        createdAt: 1000,
      );
      final event = notice.toNostrEvent(pubKey: 'a' * 64, createdAt: 1000);
      final decoded = HeadsUp.fromNostrEvent(event);
      expect(decoded.text, 'Frost tonight');
      expect(decoded.author, 'a' * 64);
      expect(decoded.scope, isNull);
      expect(decoded.isFarmWide, isTrue);
    });

    test('round-trips a role-scoped notice', () {
      final notice = HeadsUp(
        text: 'Compressor down — use icing',
        author: 'a' * 64,
        createdAt: 1000,
        scope: FarmRole.pourers,
      );
      final event = notice.toNostrEvent(pubKey: 'a' * 64, createdAt: 1000);
      final decoded = HeadsUp.fromNostrEvent(event);
      expect(decoded.scope, FarmRole.pourers);
      expect(decoded.isFarmWide, isFalse);
    });

    test('rejects a notice without text', () {
      final event = HeadsUp(
        text: 'hi',
        author: 'a',
        createdAt: 1,
      ).toNostrEvent(pubKey: 'a', createdAt: 1);
      final bad = event.copyWith(content: '{"text":""}');
      expect(
        () => HeadsUp.fromNostrEvent(bad),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
