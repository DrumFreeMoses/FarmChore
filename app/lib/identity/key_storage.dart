import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the member's secret key lives.
abstract class KeyStorage {
  Future<void> save(String nsec);
  Future<String?> load();
  Future<void> clear();
}

/// Keystore for tests and non-platform fallbacks.
class InMemoryKeyStorage implements KeyStorage {
  String? _value;
  int savedCount = 0;

  @override
  Future<void> save(String nsec) async {
    _value = nsec;
    savedCount++;
  }

  @override
  Future<String?> load() async => _value;

  @override
  Future<void> clear() async {
    _value = null;
  }
}

/// Real keystore backed by the platform secure enclave/keychain.
class SecureKeyStorage implements KeyStorage {
  SecureKeyStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'farmchore_member_nsec';

  final FlutterSecureStorage _storage;

  @override
  Future<void> save(String nsec) => _storage.write(key: _key, value: nsec);

  @override
  Future<String?> load() => _storage.read(key: _key);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
