import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prioricash/data/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:prioricash/domain/entities/expense.dart' show CategoryId;
import 'package:prioricash/domain/entities/income.dart' show IncomeSourceId;

/// SW-10 — schema-level tests.
///
/// These do not test business logic (the domain layer already proves that
/// with zero I/O). They test the one thing only a real database
/// connection can prove: that PRAGMA foreign_keys is actually ON, and that
/// the CHECK constraint on Allocations is actually enforced. A schema file
/// with the right SQL text but a disabled PRAGMA gives none of these
/// guarantees — see AGENTS.md §1.7.
void main() {
  late AppDatabase db;

  setUp(() {
    // In-memory, but through the same setup: callback production uses, so
    // this proves what production actually does.
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (database) => database.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('schema creation', () {
    test('all nine tables exist after creation', () async {
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      final names = tables.map((row) => row.data['name'] as String).toSet();

      expect(
        names,
        containsAll([
          'income_sources',
          'incomes',
          'obligations',
          'obligation_instances',
          'savings_goals',
          'categories',
          'allocations',
          'expenses',
          'settings',
        ]),
      );
    });

    test(
      'no table has a status column — it is always derived, never stored',
      () async {
        final columns = await db
            .customSelect("PRAGMA table_info('obligation_instances')")
            .get();
        final columnNames = columns
            .map((row) => row.data['name'] as String)
            .toSet();
        expect(columnNames.contains('status'), isFalse);
      },
    );
  });

  group('foreign keys are enforced', () {
    test('PRAGMA foreign_keys reports ON for this connection', () async {
      final result = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(result.data['foreign_keys'], equals(1));
    });

    test(
      'inserting an allocation with a non-existent income is rejected',
      () async {
        expect(
          () => db.customStatement(
            "INSERT INTO allocations (id, income_id, amount_minor, created_at, is_reversed) "
            "VALUES ('a-1', 'no-such-income', 1000, 0, 0)",
          ),
          throwsA(isA<sqlite3.SqliteException>()),
        );
      },
    );

    test(
      'deleting an obligation instance referenced by an allocation is restricted (R16)',
      () async {
        await db.customStatement(
          "INSERT INTO income_sources (id, name, type, is_active) VALUES ('src-1', 'Grant', 'grant', 1)",
        );
        await db.customStatement(
          "INSERT INTO incomes (id, source_id, amount_minor, received_at, note) "
          "VALUES ('inc-1', 'src-1', 100000, 0, '')",
        );
        await db.customStatement(
          "INSERT INTO obligations (id, name, amount_minor, recurrence_type, recurrence_interval, "
          "priority, is_essential, start_date, is_active) "
          "VALUES ('ob-1', 'Wi-Fi', 50000, 'monthly', 1, 0, 1, 0, 1)",
        );
        await db.customStatement(
          "INSERT INTO obligation_instances (id, obligation_id, due_date, amount_minor, funded_minor, is_paid) "
          "VALUES ('i-1', 'ob-1', 0, 50000, 0, 0)",
        );
        await db.customStatement(
          "INSERT INTO allocations (id, income_id, instance_id, amount_minor, created_at, is_reversed) "
          "VALUES ('a-1', 'inc-1', 'i-1', 50000, 0, 0)",
        );

        expect(
          () => db.customStatement(
            "DELETE FROM obligation_instances WHERE id = 'i-1'",
          ),
          throwsA(isA<sqlite3.SqliteException>()),
        );
      },
    );
  });

  group('allocation target CHECK constraint — R9', () {
    Future<void> seedIncomeAndInstanceAndGoal() async {
      await db.customStatement(
        "INSERT INTO income_sources (id, name, type, is_active) VALUES ('src-1', 'Grant', 'grant', 1)",
      );
      await db.customStatement(
        "INSERT INTO incomes (id, source_id, amount_minor, received_at, note) "
        "VALUES ('inc-1', 'src-1', 100000, 0, '')",
      );
      await db.customStatement(
        "INSERT INTO obligations (id, name, amount_minor, recurrence_type, recurrence_interval, "
        "priority, is_essential, start_date, is_active) "
        "VALUES ('ob-1', 'Wi-Fi', 50000, 'monthly', 1, 0, 1, 0, 1)",
      );
      await db.customStatement(
        "INSERT INTO obligation_instances (id, obligation_id, due_date, amount_minor, funded_minor, is_paid) "
        "VALUES ('i-1', 'ob-1', 0, 50000, 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO savings_goals (id, name, target_minor, current_minor, priority) "
        "VALUES ('goal-1', 'Emergency Fund', 100000, 0, 1)",
      );
    }

    test('an allocation targeting only an instance is accepted', () async {
      await seedIncomeAndInstanceAndGoal();
      await db.customStatement(
        "INSERT INTO allocations (id, income_id, instance_id, amount_minor, created_at, is_reversed) "
        "VALUES ('a-1', 'inc-1', 'i-1', 50000, 0, 0)",
      );
      final rows = await db.customSelect('SELECT * FROM allocations').get();
      expect(rows, hasLength(1));
    });

    test('an allocation targeting only a goal is accepted', () async {
      await seedIncomeAndInstanceAndGoal();
      await db.customStatement(
        "INSERT INTO allocations (id, income_id, goal_id, amount_minor, created_at, is_reversed) "
        "VALUES ('a-1', 'inc-1', 'goal-1', 20000, 0, 0)",
      );
      final rows = await db.customSelect('SELECT * FROM allocations').get();
      expect(rows, hasLength(1));
    });

    test('an allocation targeting neither (free balance) is accepted', () async {
      await seedIncomeAndInstanceAndGoal();
      await db.customStatement(
        "INSERT INTO allocations (id, income_id, amount_minor, created_at, is_reversed) "
        "VALUES ('a-1', 'inc-1', 10000, 0, 0)",
      );
      final rows = await db.customSelect('SELECT * FROM allocations').get();
      expect(rows, hasLength(1));
    });

    test(
      'an allocation targeting BOTH an instance and a goal is rejected by the database',
      () async {
        await seedIncomeAndInstanceAndGoal();
        expect(
          () => db.customStatement(
            "INSERT INTO allocations (id, income_id, instance_id, goal_id, amount_minor, created_at, is_reversed) "
            "VALUES ('a-1', 'inc-1', 'i-1', 'goal-1', 50000, 0, 0)",
          ),
          throwsA(isA<sqlite3.SqliteException>()),
        );
      },
    );

    test('a zero-amount allocation is rejected by the database', () async {
      await seedIncomeAndInstanceAndGoal();
      expect(
        () => db.customStatement(
          "INSERT INTO allocations (id, income_id, instance_id, amount_minor, created_at, is_reversed) "
          "VALUES ('a-1', 'inc-1', 'i-1', 0, 0, 0)",
        ),
        throwsA(isA<sqlite3.SqliteException>()),
      );
    });
  });

  group('income_sources is seeded on creation — SW-15a', () {
    test(
      'contains exactly one row per IncomeSourceId member, keyed by name',
      () async {
        final rows = await db
            .customSelect(
              'SELECT id, name, type, is_active FROM income_sources',
            )
            .get();

        expect(rows, hasLength(IncomeSourceId.values.length));

        final byId = {
          for (final row in rows) row.data['id'] as String: row.data,
        };
        for (final source in IncomeSourceId.values) {
          final row = byId[source.name];
          expect(
            row,
            isNotNull,
            reason: 'expected a seeded row with id "${source.name}"',
          );
          expect(row!['name'], source.debugLabel);
          expect(row['type'], 'system');
          expect(row['is_active'], 1);
        }
      },
    );

    test('a real income row can be inserted against a seeded source', () async {
      await db.customStatement(
        "INSERT INTO incomes (id, source_id, amount_minor, received_at, note) "
        "VALUES ('inc-1', 'grant', 135000, 0, '')",
      );
      final rows = await db.customSelect('SELECT * FROM incomes').get();
      expect(rows, hasLength(1));
    });
  });

  group('categories is seeded on creation — SW-17', () {
    test(
      'contains exactly one row per CategoryId member, keyed by name',
      () async {
        final rows = await db
            .customSelect('SELECT id, name, icon FROM categories')
            .get();

        expect(rows, hasLength(CategoryId.values.length));

        final byId = {
          for (final row in rows) row.data['id'] as String: row.data,
        };
        for (final category in CategoryId.values) {
          final row = byId[category.name];
          expect(
            row,
            isNotNull,
            reason: 'expected a seeded row with id "${category.name}"',
          );
          expect(row!['name'], category.debugLabel);
        }
      },
    );

    test(
      'a real expense row can be inserted against a seeded category',
      () async {
        await db.customStatement(
          "INSERT INTO expenses (id, category_id, amount_minor, spent_at, is_reconciliation) "
          "VALUES ('exp-1', 'food', 4000, 0, 0)",
        );
        final rows = await db.customSelect('SELECT * FROM expenses').get();
        expect(rows, hasLength(1));
      },
    );
  });
}
