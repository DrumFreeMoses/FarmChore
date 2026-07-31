import 'package:drift/drift.dart';

import 'events_table.dart';
import 'open_database_web.dart'
    if (dart.library.io) 'open_database_io.dart'
    as dbopen;

part 'app_database.g.dart';

/// Local-first database: the authoritative store on each device.
///
/// Schema v1: the signed event log (outbound queue flags included).
@DriftDatabase(tables: [Events])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.forTesting(super.e) : super();

  /// Opens (or creates) the database. On the web, data lives in IndexedDB
  /// via the sqlite3 WASM build; elsewhere in the app support directory.
  static Future<AppDatabase> open() async {
    return AppDatabase(await dbopen.openExecutor());
  }

  /// In-memory database for tests (native only).
  static Future<AppDatabase> openInMemory() => dbopen.openInMemory();

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
