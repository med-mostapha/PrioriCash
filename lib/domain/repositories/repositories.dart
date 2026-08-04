import 'package:prioricash/domain/entities/allocation.dart';
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/entities/obligation_instance.dart';
import 'package:prioricash/domain/entities/savings_goal.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/domain/entities/income.dart';
import 'package:prioricash/domain/entities/expense.dart';
import 'package:prioricash/domain/entities/settings.dart';

/// Abstract repository contracts.
///
/// Defined in domain/ so AllocationEngine and other domain services could,
/// in principle, depend on them without knowing Drift exists — see
/// AGENTS.md §2.1 and §2.3. In practice these are consumed by the
/// presentation layer, which calls into the data-layer implementations
/// below through these interfaces.

abstract class ObligationRepository {
  Future<List<Obligation>> getActive();
  Future<void> upsert(Obligation obligation);

  /// Deactivates rather than deletes — R16. An obligation with allocations
  /// against its instances can never be physically removed.
  Future<void> deactivate(String id);
}

abstract class ObligationInstanceRepository {
  Future<List<ObligationInstance>> getFundable(DateTime horizonEnd);

  /// Fully funded but not yet confirmed paid — SW-18. No date bound: a
  /// reconciliation-pending instance stays visible regardless of how long
  /// ago it was funded, since the money is still committed until the user
  /// confirms it.
  Future<List<ObligationInstance>> getFundedUnpaid();

  Future<void> insertAll(List<ObligationInstance> instances);

  /// Confirms [instanceId]'s money actually left the account — SW-18.
  /// Callers must validate via ObligationInstance.markPaid() first (it
  /// throws if not fully funded or already paid); this just persists the
  /// flag.
  Future<void> markPaid(String instanceId);
}

abstract class SavingsGoalRepository {
  Future<List<SavingsGoal>> getActive();
  Future<void> upsert(SavingsGoal goal);

  /// Deactivates rather than deletes — same rationale as
  /// ObligationRepository.deactivate (R16).
  Future<void> deactivate(String id);
}

abstract class ReconciliationRepository {
  /// Confirms [instanceId] as paid — SW-18/SW-21 fix.
  ///
  /// If [shortfall] is non-zero, first records it as an automatic Expense
  /// (isReconciliation: true) linked to the instance, so Total actually
  /// reflects the money leaving the account. Only then marks the instance
  /// paid. Both writes happen in one transaction — a partial result would
  /// leave Total wrong, which this exists specifically to prevent.
  Future<void> confirmPaid({
    required String instanceId,
    required Money shortfall,
  });
}

abstract class AllocationRepository {
  /// Persists [allocations] and applies their effect to the instances and
  /// goals they target, all inside one transaction. An interruption must
  /// leave either the complete batch or none of it — R8, AGENTS.md §1.6.
  Future<void> applyAllocations(List<Allocation> allocations);

  /// Every non-reversed allocation belonging to [incomeId], newest first.
  Future<List<Allocation>> getByIncome(String incomeId);

  /// Marks [allocations] as reversed and restores the funded amount (and,
  /// for a goal, current amount) of every affected target, inside one
  /// transaction. Mirrors [applyAllocations] in the other direction —
  /// R10, AGENTS.md §1.4.
  Future<void> applyReversal(List<Allocation> allocations);
}

/// Read-only totals not owned by any single repository above.
abstract class BalanceRepository {
  /// Sum of all income minus all expenses recorded to date.
  Future<Money> getTotalBalance();
}

abstract class IncomeRepository {
  /// Persists [income]. Its [Income.sourceId] is guaranteed to already
  /// exist as a row in income_sources — seeded once when the database is
  /// created (see app_database.dart's onCreate).
  Future<void> insert(Income income);

  /// Every recorded income, newest first — SW-21 (undo-from-UI needs a
  /// list of past incomes to pick from).
  Future<List<Income>> getAll();
}

abstract class ExpenseRepository {
  Future<void> insert(Expense expense);

  /// Sum of recorded expenses grouped by linked instanceId — feeds
  /// BalanceCalculator.reservedAmount's actualSpentByInstance (SW-18).
  Future<Map<String, Money>> getTotalsByInstance();
}

abstract class SettingsRepository {
  /// Always returns the single settings row — seeded once on database
  /// creation, so this never returns null in practice.
  Future<Settings> getSettings();

  Future<void> updateSettings(Settings settings);
}
