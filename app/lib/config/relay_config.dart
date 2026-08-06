import 'relay_config_native.dart'
    if (dart.library.js_interop) 'relay_config_web.dart'
    as platform;

/// Where the relay URL and API key live.
abstract class RelayConfigStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// Persists the relay URL and API key across app restarts.
class RelayConfig {
  RelayConfig(this._store);

  final RelayConfigStore _store;
  static const _urlKey = 'farmchore_relay_url';
  static const _apiKeyKey = 'farmchore_api_key';

  String? get url => _store.getString(_urlKey);
  String? get apiKey => _store.getString(_apiKeyKey);

  Future<void> setUrl(String url) => _store.setString(_urlKey, url);
  Future<void> setApiKey(String key) => _store.setString(_apiKeyKey, key);

  Future<void> configure({required String url, String? apiKey}) async {
    await _store.setString(_urlKey, url);
    if (apiKey != null) {
      await _store.setString(_apiKeyKey, apiKey);
    }
  }

  Future<void> clear() async {
    await _store.remove(_urlKey);
    await _store.remove(_apiKeyKey);
  }

  /// Creates a RelayConfig backed by the platform store.
  static Future<RelayConfig> create() async =>
      RelayConfig(await platform.createStore());

  /// Creates a RelayConfig backed by an in-memory store (for tests).
  static RelayConfig forTest() => RelayConfig(_MemoryStore());
}

/// In-memory store for tests — no platform dependencies.
class _MemoryStore implements RelayConfigStore {
  final _data = <String, String>{};

  @override
  String? getString(String key) => _data[key];

  @override
  Future<void> setString(String key, String value) async => _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);
}
