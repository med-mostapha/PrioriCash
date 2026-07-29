import 'package:meta/meta.dart';
import 'package:prioricash/domain/entities/obligation_instance.dart';
import 'package:prioricash/domain/value_objects/money.dart';

@immutable
class BalanceCalculator {
  const BalanceCalculator();

  /// [actualSpentByInstance] maps instanceId -> total Expense amount
  /// actually recorded against it (SW-17's linked expenses). Defaults to
  /// empty, meaning "nothing spent yet against anything" — callers that
  /// don't track spending per instance simply reserve the full funded
  /// amount for anything not yet paid, which is the safe default.
  Money reservedAmount({
    required List<ObligationInstance> instances,
    required DateTime horizonEnd,
    Map<String, Money> actualSpentByInstance = const {},
  }) {
    return instances
        .where((instance) => !instance.dueDate.isAfter(horizonEnd))
        .where((instance) => !instance.isPaid)
        .fold(Money.zero, (sum, instance) {
          if (!instance.isFullyFunded) {
            return sum.add(instance.remaining());
          }
          // Fully funded but not yet paid (SW-18): still reserved for
          // whatever hasn't actually left the wallet yet. Without this,
          // a lump-estimate obligation (e.g. Breakfast) that gets fully
          // funded on day one would free its entire balance for
          // unrelated spending before a single real purchase happened —
          // exactly the gap this project exists to prevent.
          final spent = actualSpentByInstance[instance.id] ?? Money.zero;
          final unspent = instance.fundedAmount.subtract(spent);
          return unspent.isNegative ? sum : sum.add(unspent);
        });
  }

  Money availableBalance({required Money total, required Money reserved}) {
    return total.subtract(reserved);
  }
}
