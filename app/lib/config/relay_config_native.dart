import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'relay_config.dart';

class _NativeStore implements RelayConfigStore {
  final FlutterSecureStorage _storage;
  final _cache = <String, String?>{};
  static const _prefix = 'farmchore_cfg_';

  _NativeStore(this._storage);

  /// Pre-loads cached values from secure storage.
  Future<void> load() async {
    for (final key in ['farmchore_relay_url', 'farmchore_api_key']) {
      _cache[key] = await _storage.read(key: '$_prefix$key');
    }
  }

  @override
  String? getString(String key) => _cache[key];

  @override
  Future<void> setString(String key, String value) async {
    _cache[key] = value;
    await _storage.write(key: '$_prefix$key', value: value);
  }

  @override
  Future<void> remove(String key) async {
    _cache.remove(key);
    await _storage.delete(key: '$_prefix$key');
  }
}

Future<RelayConfigStore> createStore() async {
  final store = _NativeStore(const FlutterSecureStorage());
  await store.load();
  return store;
}
