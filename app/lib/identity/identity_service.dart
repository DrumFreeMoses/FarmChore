import 'package:nostr/nostr.dart';

import 'key_storage.dart';

/// A member's identity: a Nostr keypair with no PII attached.
class MemberIdentity {
  const MemberIdentity(this.keys);

  final Keys keys;

  String get pubkey => keys.public;
  String get npub => keys.npub;
  String get nsec => keys.nsec;

  /// Hex secret, shown only during backup/import flows.
  String get hexSecret => keys.secret;
}

/// Generates, persists, and imports member identities.
class IdentityService {
  IdentityService(this._storage);

  final KeyStorage _storage;

  /// Returns the stored identity, generating and persisting one on first run.
  Future<MemberIdentity> ensureIdentity() async {
    final stored = await _storage.load();
    if (stored != null && stored.isNotEmpty) {
      return MemberIdentity(Keys(stored));
    }
    final keys = Keys.generate();
    await _storage.save(keys.nsec);
    return MemberIdentity(keys);
  }

  /// Imports an identity from a `nsec1...` or 64-char hex secret.
  Future<MemberIdentity> importIdentity(String secret) async {
    final keys = _keysFromSecret(secret);
    await _storage.save(keys.nsec);
    return MemberIdentity(keys);
  }

  Keys _keysFromSecret(String secret) {
    final trimmed = secret.trim();
    if (trimmed.length == 64 && isHex(trimmed)) {
      return Keys(trimmed);
    }
    if (trimmed.startsWith('nsec1')) {
      try {
        return Keys(trimmed);
      } catch (_) {
        throw ArgumentError('invalid nsec');
      }
    }
    throw ArgumentError(
      'secret must be a 64-char hex string or an nsec1... key',
    );
  }
}

bool isHex(String s) {
  for (final c in s.codeUnits) {
    final ok =
        (c >= 0x30 && c <= 0x39) ||
        (c >= 0x61 && c <= 0x66) ||
        (c >= 0x41 && c <= 0x46);
    if (!ok) {
      return false;
    }
  }
  return true;
}
