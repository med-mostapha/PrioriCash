import 'package:meta/meta.dart';
import 'package:prioricash/domain/entities/obligation.dart' show Priority;
import 'package:prioricash/domain/value_objects/money.dart';

/// Minimal savings-goal shape needed by [AllocationEngine].
///
/// This is deliberately not the full entity from the domain model (no
/// name, no CRUD, no isActive) — that lands in SW-19 per the backlog. Only
/// what the engine needs to decide how much surplus a goal can still
/// absorb is here.
@immutable
class SavingsGoal {
  SavingsGoal({
    required this.id,
    required this.targetAmount,
    required this.currentAmount,
    required this.priority,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (targetAmount.isZero || targetAmount.isNegative) {
      throw ArgumentError.value(
        targetAmount,
        'targetAmount',
        'must be positive',
      );
    }
    if (currentAmount.isNegative) {
      throw ArgumentError.value(
        currentAmount,
        'currentAmount',
        'must not be negative',
      );
    }
  }

  final String id;
  final Money targetAmount;
  final Money currentAmount;
  final Priority priority;

  bool get isReached => !currentAmount.compareTo(targetAmount).isNegative;

  /// How much more this goal can still absorb. Zero once reached — never
  /// negative, so the engine can safely `min(surplus, remainingCapacity())`
  /// without an extra reached-check at the call site.
  Money remainingCapacity() =>
      isReached ? Money.zero : targetAmount.subtract(currentAmount);

  /// Entity equality: identity is the id, not progress.
  @override
  bool operator ==(Object other) => other is SavingsGoal && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SavingsGoal($id, $currentAmount of $targetAmount)';
}
