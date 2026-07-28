import 'package:drift/drift.dart';
import 'package:prioricash/data/database/app_database.dart';
import 'package:prioricash/domain/entities/allocation.dart' as domain;
import 'package:prioricash/domain/entities/obligation.dart' as domain;
import 'package:prioricash/domain/entities/obligation_instance.dart' as domain;
import 'package:prioricash/domain/entities/savings_goal.dart' as domain;
import 'package:prioricash/domain/repositories/repositories.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/domain/value_objects/recurrence.dart' as domain;
import 'package:prioricash/domain/entities/income.dart' as domain;
import 'package:prioricash/domain/entities/expense.dart' as domain;

/// Drift implementations of the domain repository interfaces.
///
/// This file is the boundary where domain entities (pure Dart) meet Drift
/// rows (generated classes). Mapping happens in both directions here and
/// nowhere else — domain code never sees a Drift type, and Drift code
/// never sees a domain entity directly on the wire.

class DriftExpenseRepository implements ExpenseRepository {
  DriftExpenseRepository(this._db);
  final AppDatabase _db;

  @override
  Future<void> insert(domain.Expense expense) {
    return _db
        .into(_db.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: expense.id,
            categoryId: expense.categoryId.name,
            amountMinor: expense.amount.minorUnits,
            spentAt: expense.spentAt,
            instanceId: Value(expense.instanceId),
            isReconciliation: Value(expense.isReconciliation),
          ),
        );
  }
}

class DriftIncomeRepository implements IncomeRepository {
  DriftIncomeRepository(this._db);
  final AppDatabase _db;

  @override
  Future<void> insert(domain.Income income) {
    return _db
        .into(_db.incomes)
        .insert(
          IncomesCompanion.insert(
            id: income.id,
            sourceId: income.sourceId.name,
            amountMinor: income.amount.minorUnits,
            receivedAt: income.receivedAt,
            note: Value(income.note),
          ),
        );
  }
}

class DriftObligationRepository implements ObligationRepository {
  DriftObligationRepository(this._db);
  final AppDatabase _db;

  @override
  Future<List<domain.Obligation>> getActive() async {
    final rows = await (_db.select(
      _db.obligations,
    )..where((t) => t.isActive.equals(true))).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> upsert(domain.Obligation obligation) async {
    await _db
        .into(_db.obligations)
        .insertOnConflictUpdate(
          ObligationsCompanion.insert(
            id: obligation.id,
            name: obligation.name,
            amountMinor: obligation.amount.minorUnits,
            recurrenceType: obligation.recurrence.type.name,
            recurrenceInterval: Value(obligation.recurrence.interval),
            priority: obligation.priority.index,
            isEssential: Value(obligation.isEssential),
            startDate: obligation.startDate,
            isActive: Value(obligation.isActive),
          ),
        );
  }

  @override
  Future<void> deactivate(String id) async {
    await (_db.update(_db.obligations)..where((t) => t.id.equals(id))).write(
      const ObligationsCompanion(isActive: Value(false)),
    );
  }

  domain.Obligation _toDomain(Obligation row) {
    return domain.Obligation(
      id: row.id,
      name: row.name,
      amount: Money.fromMinor(row.amountMinor),
      recurrence: domain.Recurrence(
        domain.RecurrenceType.values.byName(row.recurrenceType),
        interval: row.recurrenceInterval,
      ),
      priority: domain.Priority.values[row.priority],
      startDate: row.startDate,
      isEssential: row.isEssential,
      isActive: row.isActive,
    );
  }
}

class DriftObligationInstanceRepository
    implements ObligationInstanceRepository {
  DriftObligationInstanceRepository(this._db);
  final AppDatabase _db;

  @override
  Future<List<domain.ObligationInstance>> getFundable(
    DateTime horizonEnd,
  ) async {
    // No lower bound on due date — R3/R4. An overdue instance's due date
    // is in the past and must still be a candidate, or a month of missed
    // payments would silently disappear from both allocation and the
    // reserved-amount total.
    final rows =
        await (_db.select(_db.obligationInstances)..where(
              (t) =>
                  t.dueDate.isSmallerOrEqualValue(horizonEnd) &
                  t.isPaid.equals(false) &
                  t.fundedMinor.isSmallerThan(t.amountMinor),
            ))
            .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> insertAll(List<domain.ObligationInstance> instances) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _db.obligationInstances,
        instances.map(_toCompanion).toList(),
      );
    });
  }

  domain.ObligationInstance _toDomain(ObligationInstance row) {
    return domain.ObligationInstance(
      id: row.id,
      obligationId: row.obligationId,
      dueDate: row.dueDate,
      amount: Money.fromMinor(row.amountMinor),
      fundedAmount: Money.fromMinor(row.fundedMinor),
      isPaid: row.isPaid,
    );
  }

  ObligationInstancesCompanion _toCompanion(domain.ObligationInstance i) {
    return ObligationInstancesCompanion.insert(
      id: i.id,
      obligationId: i.obligationId,
      dueDate: i.dueDate,
      amountMinor: i.amount.minorUnits,
      fundedMinor: Value(i.fundedAmount.minorUnits),
      isPaid: Value(i.isPaid),
    );
  }
}

class DriftSavingsGoalRepository implements SavingsGoalRepository {
  DriftSavingsGoalRepository(this._db);
  final AppDatabase _db;

  @override
  Future<List<domain.SavingsGoal>> getActive() async {
    final rows = await _db.select(_db.savingsGoals).get();
    return rows
        .map(
          (row) => domain.SavingsGoal(
            id: row.id,
            targetAmount: Money.fromMinor(row.targetMinor),
            currentAmount: Money.fromMinor(row.currentMinor),
            priority: domain.Priority.values[row.priority],
          ),
        )
        .toList();
  }
}

class DriftAllocationRepository implements AllocationRepository {
  DriftAllocationRepository(this._db);
  final AppDatabase _db;

  /// Persists every allocation and applies its effect to its target, all
  /// inside one transaction — R8. If any statement fails, the whole batch
  /// is rolled back: the ledger and the funded amounts it implies can
  /// never disagree, even under interruption.
  @override
  Future<void> applyAllocations(List<domain.Allocation> allocations) async {
    await _db.transaction(() async {
      for (final allocation in allocations) {
        await _db
            .into(_db.allocations)
            .insert(
              AllocationsCompanion.insert(
                id: allocation.id,
                incomeId: allocation.incomeId,
                instanceId: Value(allocation.instanceId),
                goalId: Value(allocation.goalId),
                amountMinor: allocation.amount.minorUnits,
                createdAt: DateTime.now(),
                isReversed: Value(allocation.isReversed),
              ),
            );

        if (allocation.instanceId != null) {
          await (_db.update(
            _db.obligationInstances,
          )..where((t) => t.id.equals(allocation.instanceId!))).write(
            ObligationInstancesCompanion.custom(
              fundedMinor:
                  _db.obligationInstances.fundedMinor +
                  Variable(allocation.amount.minorUnits),
            ),
          );
        } else if (allocation.goalId != null) {
          await (_db.update(
            _db.savingsGoals,
          )..where((t) => t.id.equals(allocation.goalId!))).write(
            SavingsGoalsCompanion.custom(
              currentMinor:
                  _db.savingsGoals.currentMinor +
                  Variable(allocation.amount.minorUnits),
            ),
          );
        }
        // Free balance (neither target set): the ledger row itself is the
        // complete record. Nothing else to update.
      }
    });
  }

  @override
  Future<List<domain.Allocation>> getByIncome(String incomeId) async {
    final rows =
        await (_db.select(_db.allocations)
              ..where((t) => t.incomeId.equals(incomeId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
    return rows.map(_toDomain).toList();
  }

  /// The exact mirror of [applyAllocations]: marks each row reversed and
  /// undoes its effect on the target, in one transaction — R10.
  @override
  Future<void> applyReversal(List<domain.Allocation> allocations) async {
    await _db.transaction(() async {
      for (final allocation in allocations) {
        await (_db.update(_db.allocations)
              ..where((t) => t.id.equals(allocation.id)))
            .write(const AllocationsCompanion(isReversed: Value(true)));

        if (allocation.instanceId != null) {
          await (_db.update(
            _db.obligationInstances,
          )..where((t) => t.id.equals(allocation.instanceId!))).write(
            ObligationInstancesCompanion.custom(
              fundedMinor:
                  _db.obligationInstances.fundedMinor -
                  Variable(allocation.amount.minorUnits),
            ),
          );
        } else if (allocation.goalId != null) {
          await (_db.update(
            _db.savingsGoals,
          )..where((t) => t.id.equals(allocation.goalId!))).write(
            SavingsGoalsCompanion.custom(
              currentMinor:
                  _db.savingsGoals.currentMinor -
                  Variable(allocation.amount.minorUnits),
            ),
          );
        }
      }
    });
  }

  domain.Allocation _toDomain(Allocation row) {
    return domain.Allocation(
      id: row.id,
      incomeId: row.incomeId,
      amount: Money.fromMinor(row.amountMinor),
      instanceId: row.instanceId,
      goalId: row.goalId,
      isReversed: row.isReversed,
    );
  }
}

class DriftBalanceRepository implements BalanceRepository {
  DriftBalanceRepository(this._db);
  final AppDatabase _db;

  @override
  Future<Money> getTotalBalance() async {
    final incomeTotal = await _db
        .customSelect(
          'SELECT COALESCE(SUM(amount_minor), 0) AS total FROM incomes',
        )
        .getSingle();
    final expenseTotal = await _db
        .customSelect(
          'SELECT COALESCE(SUM(amount_minor), 0) AS total FROM expenses',
        )
        .getSingle();

    final income = incomeTotal.data['total'] as int;
    final expense = expenseTotal.data['total'] as int;
    return Money.fromMinor(income).subtract(Money.fromMinor(expense));
  }
}
