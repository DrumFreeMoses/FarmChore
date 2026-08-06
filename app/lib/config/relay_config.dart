import 'package:shared_preferences/shared_preferences.dart';

/// Persists the relay URL and API key across app restarts.
class RelayConfig {
  RelayConfig(this._prefs);

  final SharedPreferences _prefs;
  static const _urlKey = 'farmchore_relay_url';
  static const _apiKeyKey = 'farmchore_api_key';

  /// The currently-configured relay URL, or null if not yet set.
  String? get url => _prefs.getString(_urlKey);

  /// The API key for relay authentication, or null if none.
  String? get apiKey => _prefs.getString(_apiKeyKey);

  /// Saves the relay URL (called after scanning a QR code).
  Future<void> setUrl(String url) => _prefs.setString(_urlKey, url);

  /// Saves the API key.
  Future<void> setApiKey(String key) => _prefs.setString(_apiKeyKey, key);

  /// Saves both URL and API key at once.
  Future<void> configure({required String url, String? apiKey}) async {
    await _prefs.setString(_urlKey, url);
    if (apiKey != null) {
      await _prefs.setString(_apiKeyKey, apiKey);
    }
  }

  /// Clears the stored URL and key, reverting to build-time defaults.
  Future<void> clear() async {
    await _prefs.remove(_urlKey);
    await _prefs.remove(_apiKeyKey);
  }
}
