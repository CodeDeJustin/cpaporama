import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

class Nights extends Table {
  TextColumn get nightKey => text()(); // YYYYMMDD (frontière midi)
  IntColumn get nightDateEpochDay => integer()(); // local date -> epoch day

  IntColumn get startEpochMs => integer()();
  IntColumn get endEpochMs => integer()();

  IntColumn get sessionsCount => integer()();
  IntColumn get gapCount => integer().withDefault(const Constant(0))();
  IntColumn get gapSeconds => integer().withDefault(const Constant(0))();

  IntColumn get useSeconds => integer().withDefault(const Constant(0))();

  TextColumn get labelsJson => text().nullable()(); // ["Flow","Mask Pres",...]
  IntColumn get updatedAtEpochMs => integer()();

  @override
  Set<Column> get primaryKey => {nightKey};
}

class Sessions extends Table {
  TextColumn get sessionKey => text()(); // YYYYMMDD_HHMMSS
  TextColumn get nightKey => text().references(Nights, #nightKey)();

  IntColumn get startEpochMs => integer()();
  IntColumn get durationSeconds => integer().nullable()();

  TextColumn get bestType => text()(); // PLD/BRP/...
  TextColumn get bestFilePath => text()(); // chemin local complet
  TextColumn get typesCsv => text()(); // "BRP,PLD,SA2"

  @override
  Set<Column> get primaryKey => {sessionKey};
}

@DriftDatabase(tables: [Meta, Nights, Sessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    // Drift recommande drift_flutter pour Flutter, avec DB en Application Support.
    return driftDatabase(
      name: 'cpaporama_db',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }

  // Helpers meta
  Future<String?> metaGet(String k) async {
    final row = await (select(meta)..where((m) => m.key.equals(k))).getSingleOrNull();
    return row?.value;
  }

  Future<void> metaSet(String k, String v) async {
    await into(meta).insertOnConflictUpdate(MetaCompanion.insert(key: k, value: Value(v)));
  }

  Future<void> metaDelete(String k) async {
    await (delete(meta)..where((m) => m.key.equals(k))).go();
  }
}
