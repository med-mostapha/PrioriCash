import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:prioricash/data/database/tables.dart';

part 'app_database.g.dart';

/// The app's single Drift database.
///
/// SW-10. No migrations in v1 per BACKLOG.md's locked decisions: any schema
/// change means dropping and recreating the database, since there is one
/// user and no production data yet.
@DriftDatabase(
  tables: [
    IncomeSources,
    Incomes,
    Obligations,
    ObligationInstances,
    SavingsGoals,
    Categories,
    Allocations,
    Expenses,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Only for data-layer tests exercising the schema itself (SW-11). Domain
  /// tests never touch this — they run on plain Dart objects with no
  /// database at all.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // No migrations in v1 — see the class doc comment. If schemaVersion
    // ever needs to change, the answer is onCreate from scratch, not an
    // upgrade path.
    onCreate: (m) => m.createAll(),
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'prioricash.sqlite'));
    return NativeDatabase.createInBackground(
      file,
      // PRAGMA foreign_keys is OFF by default in SQLite. Without this, the
      // CHECK constraint on Allocations and every references(...) in
      // tables.dart are silently unenforced — see AGENTS.md §1.7.
      setup: (database) {
        database.execute('PRAGMA foreign_keys = ON;');
      },
    );
  });
}
