import 'package:meta/meta.dart';
import 'package:prioricash/domain/entities/allocation.dart';
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/entities/obligation_instance.dart';
import 'package:prioricash/domain/entities/savings_goal.dart';
import 'package:prioricash/domain/value_objects/money.dart';

/// Distributes one income across obligation instances and savings goals.
///
/// Pure domain service: given the same inputs it always produces the same
/// output, and it never touches storage. The caller (the data layer) loads
/// the candidate instances and goals and persists the result inside one
/// transaction. See AGENTS.md §2.2 and §1.6.
///
/// Order of allocation, in this exact sequence:
///   1. Essential instances, earliest due date first, priority as
///      tie-breaker (R6, R7).
///   2. Savings goals, highest priority first, once every essential
///      instance is fully funded.
///   3. Discretionary instances, from whatever surplus remains.
///   4. Whatever is still left becomes free balance (R9) — an allocation
///      with neither an instance nor a goal target.
@immutable
class AllocationEngine {
  const AllocationEngine();

  /// Runs one allocation pass for [incomeAmount].
  ///
  /// [obligationsById] must contain an entry for every obligation
  /// referenced by [instances] — it is how the engine learns whether each
  /// instance's parent obligation is essential.
  List<Allocation> allocate({
    required String incomeId,
    required Money incomeAmount,
    required List<ObligationInstance> instances,
    required Map<String, Obligation> obligationsById,
    required List<SavingsGoal> goals,
    required DateTime today,
  }) {
    var remaining = incomeAmount;
    final allocations = <Allocation>[];
    var sequence = 0;

    if (remaining.isZero || remaining.isNegative) {
      return const [];
    }

    final essentials = <ObligationInstance>[];
    final discretionary = <ObligationInstance>[];

    for (final instance in instances) {
      if (instance.isFullyFunded) {
        continue;
      }
      final obligation = obligationsById[instance.obligationId];
      if (obligation == null) {
        throw ArgumentError(
          'No obligation found for instance ${instance.id} '
          '(obligationId: ${instance.obligationId})',
        );
      }
      (obligation.isEssential ? essentials : discretionary).add(instance);
    }

    _sortByDueDateThenPriority(essentials, obligationsById);
    _sortByDueDateThenPriority(discretionary, obligationsById);

    for (final instance in essentials) {
      if (remaining.isZero) break;
      final payment = remaining.min(instance.remaining());
      if (payment.isZero) continue;
      allocations.add(
        Allocation(
          id: _allocationId(incomeId, sequence++),
          incomeId: incomeId,
          amount: payment,
          instanceId: instance.id,
        ),
      );
      remaining = remaining.subtract(payment);
    }

    final sortedGoals = [...goals]
      ..sort((a, b) => a.priority.index.compareTo(b.priority.index));
    for (final goal in sortedGoals) {
      if (remaining.isZero) break;
      final payment = remaining.min(goal.remainingCapacity());
      if (payment.isZero) continue;
      allocations.add(
        Allocation(
          id: _allocationId(incomeId, sequence++),
          incomeId: incomeId,
          amount: payment,
          goalId: goal.id,
        ),
      );
      remaining = remaining.subtract(payment);
    }

    for (final instance in discretionary) {
      if (remaining.isZero) break;
      final payment = remaining.min(instance.remaining());
      if (payment.isZero) continue;
      allocations.add(
        Allocation(
          id: _allocationId(incomeId, sequence++),
          incomeId: incomeId,
          amount: payment,
          instanceId: instance.id,
        ),
      );
      remaining = remaining.subtract(payment);
    }

    if (!remaining.isZero) {
      allocations.add(
        Allocation(
          id: _allocationId(incomeId, sequence++),
          incomeId: incomeId,
          amount: remaining,
        ),
      );
    }

    return allocations;
  }

  /// R6: due date ascending, then priority ascending as a tie-breaker.
  void _sortByDueDateThenPriority(
    List<ObligationInstance> list,
    Map<String, Obligation> obligationsById,
  ) {
    list.sort((a, b) {
      final byDate = a.dueDate.compareTo(b.dueDate);
      if (byDate != 0) return byDate;
      final priorityA = obligationsById[a.obligationId]!.priority.index;
      final priorityB = obligationsById[b.obligationId]!.priority.index;
      return priorityA.compareTo(priorityB);
    });
  }

  static String _allocationId(String incomeId, int sequence) =>
      '$incomeId#alloc-$sequence';
}
