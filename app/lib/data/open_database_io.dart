import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'app_database.dart';

/// Opens the on-disk database in the app support directory.
Future<QueryExecutor> openExecutor() async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'farmchore.sqlite'));
  return LazyDatabase(() async => NativeDatabase(file));
}

/// In-memory database for tests.
Future<AppDatabase> openInMemory() async {
  return AppDatabase(NativeDatabase.memory());
}
