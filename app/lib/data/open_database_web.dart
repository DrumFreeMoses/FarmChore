import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

import 'app_database.dart';

/// Opens the database on the web: sqlite3 compiled to WASM, persisted in
/// IndexedDB through drift's virtual file system.
Future<QueryExecutor> openExecutor() async {
  final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  final fs = await IndexedDbFileSystem.open(dbName: 'farmchore');
  sqlite3.registerVirtualFileSystem(fs, makeDefault: true);
  return WasmDatabase(sqlite3: sqlite3, path: 'farmchore.sqlite');
}

/// In-memory databases are native-only (used by the test suite).
Future<AppDatabase> openInMemory() async {
  throw UnsupportedError('in-memory databases are only available on native');
}
