import 'package:web/web.dart' as web;

import 'relay_config.dart';

class _WebStore implements RelayConfigStore {
  @override
  String? getString(String key) => web.window.localStorage.getItem(key);

  @override
  Future<void> setString(String key, String value) async {
    web.window.localStorage.setItem(key, value);
  }

  @override
  Future<void> remove(String key) async {
    web.window.localStorage.removeItem(key);
  }
}

Future<RelayConfigStore> createStore() async => _WebStore();
