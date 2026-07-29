import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prioricash/data/database/app_database.dart'
    hide Obligation, Allocation, Income, Expense;
import 'package:prioricash/domain/entities/expense.dart';
import 'package:prioricash/data/repositories/drift_repositories.dart';
import 'package:prioricash/domain/entities/allocation.dart';
import 'package:prioricash/domain/entities/income.dart'
    show Income, IncomeSourceId;
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/services/allocation_engine.dart';
import 'package:prioricash/domain/services/instance_generator.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/domain/value_objects/recurrence.dart';

/// SW-11 — Repository tests.
///
/// This is the same generate -> allocate -> apply -> undo cycle proven
/// with hand-written applyAllocations() in SW-9's acceptance criteria
/// suite, now run against the real database through the real repository.
void main() {
  DateTime d(int year, int month, int day) => DateTime(year, month, day);

  late AppDatabase db;
  late DriftObligationRepository obligationRepo;
  late DriftObligationInstanceRepository instanceRepo;
  late DriftAllocationRepository allocationRepo;

  const generator = InstanceGenerator();
  const engine = AllocationEngine();

  setUp(() async {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (database) => database.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    obligationRepo = DriftObligationRepository(db);
    instanceRepo = DriftObligationInstanceRepository(db);
    allocationRepo = DriftAllocationRepository(db);

    await db.customStatement(
      "INSERT INTO income_sources (id, name, type, is_active) VALUES ('src-1', 'Grant', 'grant', 1)",
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedIncome(String id, int amountMinor) => db.customStatement(
    "INSERT INTO incomes (id, source_id, amount_minor, received_at, note) "
    "VALUES ('$id', 'src-1', $amountMinor, 0, '')",
  );

  group('ObligationRepository', () {
    test('upsert then getActive round-trips an obligation exactly', () async {
      final ob = Obligation(
        id: 'ob-1',
        name: 'Wi-Fi',
        amount: Money.fromMinor(50000),
        recurrence: const Recurrence(RecurrenceType.monthly),
        priority: Priority.high,
        startDate: d(2026, 1, 5),
      );

      await obligationRepo.upsert(ob);
      final result = await obligationRepo.getActive();

      expect(result, hasLength(1));
      expect(result.single.id, equals('ob-1'));
      expect(result.single.amount, equals(Money.fromMinor(50000)));
      expect(result.single.priority, equals(Priority.high));
    });

    test(
      'deactivate excludes the obligation from getActive without deleting it',
      () async {
        final ob = Obligation(
          id: 'ob-1',
          name: 'Wi-Fi',
          amount: Money.fromMinor(50000),
          recurrence: const Recurrence(RecurrenceType.monthly),
          priority: Priority.high,
          startDate: d(2026, 1, 5),
        );
        await obligationRepo.upsert(ob);

        await obligationRepo.deactivate('ob-1');
        final active = await obligationRepo.getActive();

        expect(active, isEmpty);
        final rows = await db.customSelect('SELECT * FROM obligations').get();
        expect(rows, hasLength(1));
      },
    );
  });

  group('IncomeRepository', () {
    late DriftIncomeRepository incomeRepo;

    setUp(() {
      incomeRepo = DriftIncomeRepository(db);
    });

    test(
      'insert round-trips all fields, including default empty note',
      () async {
        final income = Income(
          id: 'inc-1',
          sourceId: IncomeSourceId.grant,
          amount: Money.fromMinor(135000),
          receivedAt: d(2026, 7, 1),
        );

        await incomeRepo.insert(income);

        final row =
            (await db.customSelect('SELECT * FROM incomes').get()).single;
        expect(row.data['id'], 'inc-1');
        expect(row.data['source_id'], 'grant');
        expect(row.data['amount_minor'], 135000);
        expect(row.data['note'], '');
      },
    );

    test(
      'insert with a non-grant source and a note round-trips correctly',
      () async {
        final income = Income(
          id: 'inc-2',
          sourceId: IncomeSourceId.freelance,
          amount: Money.fromMinor(50000),
          receivedAt: d(2026, 7, 15),
          note: 'logo design job',
        );

        await incomeRepo.insert(income);

        final row =
            (await db
                    .customSelect("SELECT * FROM incomes WHERE id = 'inc-2'")
                    .get())
                .single;
        expect(row.data['source_id'], 'freelance');
        expect(row.data['amount_minor'], 50000);
        expect(row.data['note'], 'logo design job');
      },
    );
  });

  group('ObligationInstanceRepository — R3/R4', () {
    test(
      'getFundable includes an overdue instance with no lower date bound',
      () async {
        final ob = Obligation(
          id: 'ob-1',
          name: 'Wi-Fi',
          amount: Money.fromMinor(50000),
          recurrence: const Recurrence(RecurrenceType.monthly),
          priority: Priority.high,
          startDate: d(2026, 1, 5),
        );
        await obligationRepo.upsert(ob);

        final instances = generator.generate(
          obligation: ob,
          horizonEnd: d(2026, 4, 14),
          existing: const [],
        );
        await instanceRepo.insertAll(instances);

        final fundable = await instanceRepo.getFundable(d(2026, 4, 14));

        expect(fundable, hasLength(4));
        expect(
          fundable.map((i) => i.dueDate),
          containsAll([
            d(2026, 1, 5),
            d(2026, 2, 5),
            d(2026, 3, 5),
            d(2026, 4, 5),
          ]),
        );
      },
    );

    test('getFundable excludes a fully funded instance', () async {
      final ob = Obligation(
        id: 'ob-1',
        name: 'Wi-Fi',
        amount: Money.fromMinor(50000),
        recurrence: const Recurrence(RecurrenceType.monthly),
        priority: Priority.high,
        startDate: d(2026, 3, 5),
      );
      await obligationRepo.upsert(ob);

      final instances = generator.generate(
        obligation: ob,
        horizonEnd: d(2026, 3, 31),
        existing: const [],
      );
      final funded = instances.single.applyFunding(Money.fromMinor(50000));
      await instanceRepo.insertAll([funded]);

      final fundable = await instanceRepo.getFundable(d(2026, 3, 31));
      expect(fundable, isEmpty);
    });
  });
  test('getFundedUnpaid returns a fully-funded, unpaid instance', () async {
    final ob = Obligation(
      id: 'ob-1',
      name: 'Wi-Fi',
      amount: Money.fromMinor(50000),
      recurrence: const Recurrence(RecurrenceType.monthly),
      priority: Priority.high,
      startDate: d(2026, 3, 5),
    );
    await obligationRepo.upsert(ob);
    final instances = generator.generate(
      obligation: ob,
      horizonEnd: d(2026, 3, 31),
      existing: const [],
    );
    final funded = instances.single.applyFunding(Money.fromMinor(50000));
    await instanceRepo.insertAll([funded]);

    final result = await instanceRepo.getFundedUnpaid();

    expect(result, hasLength(1));
    expect(result.single.id, equals(funded.id));
  });

  test('getFundedUnpaid excludes a partially funded instance', () async {
    final ob = Obligation(
      id: 'ob-1',
      name: 'Wi-Fi',
      amount: Money.fromMinor(50000),
      recurrence: const Recurrence(RecurrenceType.monthly),
      priority: Priority.high,
      startDate: d(2026, 3, 5),
    );
    await obligationRepo.upsert(ob);
    final instances = generator.generate(
      obligation: ob,
      horizonEnd: d(2026, 3, 31),
      existing: const [],
    );
    final partial = instances.single.applyFunding(Money.fromMinor(20000));
    await instanceRepo.insertAll([partial]);

    final result = await instanceRepo.getFundedUnpaid();

    expect(result, isEmpty);
  });

  test('markPaid removes the instance from getFundedUnpaid', () async {
    final ob = Obligation(
      id: 'ob-1',
      name: 'Wi-Fi',
      amount: Money.fromMinor(50000),
      recurrence: const Recurrence(RecurrenceType.monthly),
      priority: Priority.high,
      startDate: d(2026, 3, 5),
    );
    await obligationRepo.upsert(ob);
    final instances = generator.generate(
      obligation: ob,
      horizonEnd: d(2026, 3, 31),
      existing: const [],
    );
    final funded = instances.single.applyFunding(Money.fromMinor(50000));
    await instanceRepo.insertAll([funded]);

    await instanceRepo.markPaid(funded.id);
    final result = await instanceRepo.getFundedUnpaid();

    expect(result, isEmpty);
  });
  group('AllocationRepository — transactional apply and reversal', () {
    test(
      'applyAllocations persists the ledger and funds the target instance',
      () async {
        final ob = Obligation(
          id: 'ob-1',
          name: 'Wi-Fi',
          amount: Money.fromMinor(50000),
          recurrence: const Recurrence(RecurrenceType.monthly),
          priority: Priority.high,
          startDate: d(2026, 3, 5),
        );
        await obligationRepo.upsert(ob);
        final instances = generator.generate(
          obligation: ob,
          horizonEnd: d(2026, 3, 31),
          existing: const [],
        );
        await instanceRepo.insertAll(instances);
        await seedIncome('inc-1', 50000);

        final allocations = engine.allocate(
          incomeId: 'inc-1',
          incomeAmount: Money.fromMinor(50000),
          instances: instances,
          obligationsById: {'ob-1': ob},
          goals: const [],
          today: d(2026, 3, 15),
        );

        await allocationRepo.applyAllocations(allocations);

        final ledger = await allocationRepo.getByIncome('inc-1');
        expect(ledger, hasLength(1));
        expect(ledger.single.amount, equals(Money.fromMinor(50000)));

        final updated = await instanceRepo.getFundable(d(2026, 4, 14));
        expect(updated, isEmpty);
      },
    );

    test(
      'applyAllocations records a free-balance row with no target',
      () async {
        await seedIncome('inc-1', 30000);
        final allocations = engine.allocate(
          incomeId: 'inc-1',
          incomeAmount: Money.fromMinor(30000),
          instances: const [],
          obligationsById: const {},
          goals: const [],
          today: d(2026, 3, 15),
        );

        await allocationRepo.applyAllocations(allocations);

        final ledger = await allocationRepo.getByIncome('inc-1');
        expect(ledger.single.isFreeBalance, isTrue);
      },
    );

    test(
      'applyReversal restores the exact prior funded amount — acceptance criterion 4',
      () async {
        final ob = Obligation(
          id: 'ob-1',
          name: 'Wi-Fi',
          amount: Money.fromMinor(50000),
          recurrence: const Recurrence(RecurrenceType.monthly),
          priority: Priority.high,
          startDate: d(2026, 3, 5),
        );
        await obligationRepo.upsert(ob);
        final instances = generator.generate(
          obligation: ob,
          horizonEnd: d(2026, 3, 31),
          existing: const [],
        );
        await instanceRepo.insertAll(instances);
        await seedIncome('inc-1', 30000);

        final allocations = engine.allocate(
          incomeId: 'inc-1',
          incomeAmount: Money.fromMinor(30000),
          instances: instances,
          obligationsById: {'ob-1': ob},
          goals: const [],
          today: d(2026, 3, 15),
        );
        await allocationRepo.applyAllocations(allocations);

        final beforeReversal = await instanceRepo.getFundable(d(2026, 4, 14));
        expect(
          beforeReversal.single.fundedAmount,
          equals(Money.fromMinor(30000)),
        );

        final ledger = await allocationRepo.getByIncome('inc-1');
        final reversed = engine.undo(incomeId: 'inc-1', allocations: ledger);
        await allocationRepo.applyReversal(reversed);

        final afterReversal = await instanceRepo.getFundable(d(2026, 4, 14));
        expect(afterReversal.single.fundedAmount, equals(Money.zero));

        final finalLedger = await allocationRepo.getByIncome('inc-1');
        expect(finalLedger.every((a) => a.isReversed), isTrue);
      },
    );

    test('an interrupted batch cannot leave a partial ledger', () async {
      await seedIncome('inc-1', 50000);
      final badBatch = [
        Allocation(
          id: 'a-1',
          incomeId: 'inc-1',
          amount: Money.fromMinor(20000),
          instanceId: 'no-such-instance',
        ),
        Allocation(
          id: 'a-2',
          incomeId: 'inc-1',
          amount: Money.fromMinor(30000),
        ),
      ];

      await expectLater(
        () => allocationRepo.applyAllocations(badBatch),
        throwsA(anything),
      );

      final ledger = await allocationRepo.getByIncome('inc-1');
      expect(ledger, isEmpty);
    });
  });

  group('ExpenseRepository', () {
    late DriftExpenseRepository expenseRepo;

    setUp(() {
      expenseRepo = DriftExpenseRepository(db);
    });
    test(
      'getTotalsByInstance sums linked expenses per instance, ignoring unlinked ones',
      () async {
        final ob = Obligation(
          id: 'ob-breakfast',
          name: 'Breakfast',
          amount: Money.fromMinor(110000),
          recurrence: const Recurrence(RecurrenceType.monthly),
          priority: Priority.medium,
          startDate: d(2026, 7, 1),
        );
        await obligationRepo.upsert(ob);
        final instances = generator.generate(
          obligation: ob,
          horizonEnd: d(2026, 7, 31),
          existing: const [],
        );
        await instanceRepo.insertAll(instances);
        final instanceId = instances.single.id;

        await expenseRepo.insert(
          Expense(
            id: 'exp-1',
            categoryId: CategoryId.food,
            amount: Money.fromMinor(4000),
            spentAt: d(2026, 7, 10),
            instanceId: instanceId,
          ),
        );
        await expenseRepo.insert(
          Expense(
            id: 'exp-2',
            categoryId: CategoryId.food,
            amount: Money.fromMinor(3500),
            spentAt: d(2026, 7, 15),
            instanceId: instanceId,
          ),
        );
        await expenseRepo.insert(
          Expense(
            id: 'exp-3',
            categoryId: CategoryId.other,
            amount: Money.fromMinor(9999),
            spentAt: d(2026, 7, 20),
          ),
        );

        final totals = await expenseRepo.getTotalsByInstance();

        expect(totals, hasLength(1));
        expect(totals[instanceId], equals(Money.fromMinor(7500)));
      },
    );

    test('getTotalsByInstance is empty when nothing is linked', () async {
      await expenseRepo.insert(
        Expense(
          id: 'exp-1',
          categoryId: CategoryId.other,
          amount: Money.fromMinor(1000),
          spentAt: d(2026, 7, 10),
        ),
      );

      final totals = await expenseRepo.getTotalsByInstance();

      expect(totals, isEmpty);
    });
    test('insert round-trips all fields, unlinked by default', () async {
      final expense = Expense(
        id: 'exp-1',
        categoryId: CategoryId.food,
        amount: Money.fromMinor(4000),
        spentAt: d(2026, 7, 28),
      );

      await expenseRepo.insert(expense);

      final row =
          (await db.customSelect('SELECT * FROM expenses').get()).single;
      expect(row.data['id'], 'exp-1');
      expect(row.data['category_id'], 'food');
      expect(row.data['amount_minor'], 4000);
      expect(row.data['instance_id'], isNull);
      expect(row.data['is_reconciliation'], 0);
    });

    test(
      'insert with an obligation-instance link round-trips correctly',
      () async {
        final ob = Obligation(
          id: 'ob-breakfast',
          name: 'Breakfast',
          amount: Money.fromMinor(110000),
          recurrence: const Recurrence(RecurrenceType.monthly),
          priority: Priority.medium,
          startDate: d(2026, 7, 1),
        );
        await obligationRepo.upsert(ob);
        final instances = generator.generate(
          obligation: ob,
          horizonEnd: d(2026, 7, 31),
          existing: const [],
        );
        await instanceRepo.insertAll(instances);

        final expense = Expense(
          id: 'exp-2',
          categoryId: CategoryId.food,
          amount: Money.fromMinor(4000),
          spentAt: d(2026, 7, 28),
          instanceId: instances.single.id,
        );

        await expenseRepo.insert(expense);

        final row =
            (await db
                    .customSelect("SELECT * FROM expenses WHERE id = 'exp-2'")
                    .get())
                .single;
        expect(row.data['instance_id'], instances.single.id);
      },
    );
  });
}
