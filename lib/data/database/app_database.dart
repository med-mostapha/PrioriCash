import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:prioricash/data/database/tables.dart';
import 'package:prioricash/domain/entities/expense.dart' show CategoryId;
import 'package:prioricash/domain/entities/income.dart' show IncomeSourceId;
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
    onCreate: (m) async {
      await m.createAll();
      await _seedIncomeSources(this);
      await _seedCategories(this);
    },
  );

  /// Populates `income_sources` with one row per [IncomeSourceId] member,
  /// run once as part of database creation.
  ///
  /// `Income.sourceId` persists the enum member's name verbatim as the FK
  /// target (see the doc comment on [IncomeSourceId] in income.dart), so
  /// these rows must exist before any real income can be recorded — the
  /// `IncomeSources` foreign key (§1.7, PRAGMA foreign_keys = ON) rejects
  /// the insert otherwise. `type` is fixed at `'system'`: every member here
  /// is a built-in source, not a user-defined one — there is no
  /// user-defined source type in v1.
  Future<void> _seedIncomeSources(AppDatabase db) {
    return db.batch((batch) {
      batch.insertAll(db.incomeSources, [
        for (final source in IncomeSourceId.values)
          IncomeSourcesCompanion.insert(
            id: source.name,
            name: source.debugLabel,
            type: 'system',
          ),
      ]);
    });
  }

  /// Populates `categories` with one row per [CategoryId] member, run once
  /// as part of database creation — same rationale as [_seedIncomeSources],
  /// mirrored for `Expense.categoryId` (SW-17).
  Future<void> _seedCategories(AppDatabase db) {
    return db.batch((batch) {
      batch.insertAll(db.categories, [
        for (final category in CategoryId.values)
          CategoriesCompanion.insert(
            id: category.name,
            name: category.debugLabel,
          ),
      ]);
    });
  }
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
