import 'package:prioricash/domain/entities/allocation.dart';
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/entities/obligation_instance.dart';
import 'package:prioricash/domain/entities/savings_goal.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/domain/entities/income.dart';

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
  /// Every instance due on or before [horizonEnd], with no lower date
  /// bound — R3/R4. Overdue instances (due date in the past) must be
  /// included, or accumulated overdue commitments silently vanish from
  /// both the allocation candidate set and the reserved-amount total.
  Future<List<ObligationInstance>> getFundable(DateTime horizonEnd);

  Future<void> insertAll(List<ObligationInstance> instances);
}

abstract class SavingsGoalRepository {
  Future<List<SavingsGoal>> getActive();
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
}
