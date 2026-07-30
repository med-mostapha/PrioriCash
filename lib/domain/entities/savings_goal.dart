import 'package:meta/meta.dart';
import 'package:prioricash/domain/entities/obligation.dart' show Priority;
import 'package:prioricash/domain/value_objects/money.dart';

/// A savings target the person is working toward — SW-19 (full CRUD
/// shape, expanded from the SW-6 minimal version).
///
/// [AllocationEngine] only ever reads targetAmount/currentAmount/priority
/// (see remainingCapacity()) — name and isActive exist purely for the
/// CRUD screen and for deactivating a goal without losing its funding
/// history, same rationale as Obligation.isActive (R16).
@immutable
class SavingsGoal {
  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.priority,
    this.isActive = true,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
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
  final String name;
  final Money targetAmount;
  final Money currentAmount;
  final Priority priority;

  /// Deactivated goals stop receiving new allocations but keep their
  /// funding history — mirrors Obligation.isActive (R16).
  final bool isActive;

  bool get isReached => !currentAmount.compareTo(targetAmount).isNegative;

  /// How much more this goal can still absorb. Zero once reached — never
  /// negative, so the engine can safely `min(surplus, remainingCapacity())`
  /// without an extra reached-check at the call site.
  Money remainingCapacity() =>
      isReached ? Money.zero : targetAmount.subtract(currentAmount);

  SavingsGoal deactivate() => copyWith(isActive: false);

  SavingsGoal copyWith({
    String? name,
    Money? targetAmount,
    Money? currentAmount,
    Priority? priority,
    bool? isActive,
  }) {
    return SavingsGoal(
      id: id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Entity equality: identity is the id, not progress or name.
  @override
  bool operator ==(Object other) => other is SavingsGoal && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SavingsGoal($id, $name, $currentAmount of $targetAmount)';
}
