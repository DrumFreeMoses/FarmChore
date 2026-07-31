import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'events_table.dart';

part 'app_database.g.dart';

/// Local-first database: the authoritative store on each device.
///
/// Schema v1: the signed event log (outbound queue flags included).
@DriftDatabase(tables: [Events])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.forTesting(super.e) : super();

  /// Opens (or creates) the on-disk database in the app support directory.
  static Future<AppDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'farmchore.sqlite'));
    return AppDatabase(LazyDatabase(() async => NativeDatabase(file)));
  }

  static Future<AppDatabase> openInMemory() async {
    return AppDatabase(NativeDatabase.memory());
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
  );

  /// Events with a given NIP-01 kind, oldest first.
  Selectable<Event> eventsForKind(int kind) =>
      (select(events)..where((e) => e.kind.equals(kind)))
        ..orderBy([(e) => OrderingTerm.asc(e.createdAt)]);

  /// Locally-queued events awaiting relay acknowledgement.
  Selectable<Event> pendingEvents() =>
      select(events)..where((e) => e.sent.equals(false));
}
