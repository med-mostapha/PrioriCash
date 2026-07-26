import 'package:meta/meta.dart';
import 'package:prioricash/domain/value_objects/money.dart';

@immutable
class Allocation {
  Allocation({
    required this.id,
    required this.incomeId,
    required this.amount,
    this.instanceId,
    this.goalId,
    this.isReversed = false,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (incomeId.isEmpty) {
      throw ArgumentError.value(incomeId, 'incomeId', 'must not be empty');
    }
    if (amount.isZero || amount.isNegative) {
      throw ArgumentError.value(amount, 'amount', 'must be positive');
    }
    if (instanceId != null && goalId != null) {
      throw ArgumentError(
        'Allocation cannot target both an instance and a goal',
      );
    }
  }

  final String id;
  final String incomeId;

  /// The amount moved. Always positive — direction is implicit: money flows
  /// from the income towards the target.
  final Money amount;

  /// Set when this allocation funds an obligation instance.
  final String? instanceId;

  /// Set when this allocation funds a savings goal.
  final String? goalId;

  /// True once undone. The row stays forever — see AGENTS.md §1.4.
  final bool isReversed;

  /// Neither target set: unallocated surplus. SRS R9.
  bool get isFreeBalance => instanceId == null && goalId == null;

  String get targetKind {
    if (instanceId != null) return 'instance';
    if (goalId != null) return 'goal';
    return 'free';
  }

  /// A fresh, reversed copy. Never mutates — never deletes. SRS R10.
  Allocation reverse() {
    if (isReversed) {
      throw StateError('Allocation $id is already reversed');
    }
    return Allocation(
      id: id,
      incomeId: incomeId,
      amount: amount,
      instanceId: instanceId,
      goalId: goalId,
      isReversed: true,
    );
  }

  /// Entity equality: identity is the id, not reversal state.
  @override
  bool operator ==(Object other) => other is Allocation && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Allocation($id, $amount -> $targetKind${isReversed ? ', reversed' : ''})';
}
