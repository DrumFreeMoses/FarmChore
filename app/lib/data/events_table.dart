import 'package:drift/drift.dart';

/// The event log: every local write is a row here before sync.
class Events extends Table {
  /// NIP-01 event id (sha256 of canonical serialization).
  TextColumn get id => text()();

  TextColumn get pubkey => text()();

  /// NIP-01 kind: 31500..31503 for FarmChore domain data.
  IntColumn get kind => integer()();

  IntColumn get createdAt => integer()();

  TextColumn get content => text()();

  /// 128-char hex Schnorr signature; '' while locally queued.
  TextColumn get sig => text().withDefault(const Constant(''))();

  /// JSON-encoded tag array.
  TextColumn get tags => text().withDefault(const Constant('[]'))();

  /// Whether the relay has acknowledged this event.
  BoolColumn get sent => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
