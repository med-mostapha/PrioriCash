import 'package:meta/meta.dart';
import 'package:prioricash/domain/entities/obligation_instance.dart';
import 'package:prioricash/domain/value_objects/money.dart';

@immutable
class BalanceCalculator {
  const BalanceCalculator();

  Money reservedAmount({
    required List<ObligationInstance> instances,
    required DateTime horizonEnd,
  }) {
    return instances
        .where((instance) => !instance.dueDate.isAfter(horizonEnd))
        .where((instance) => !instance.isPaid && !instance.isFullyFunded)
        .fold(Money.zero, (sum, instance) => sum.add(instance.remaining()));
  }

  Money availableBalance({required Money total, required Money reserved}) {
    return total.subtract(reserved);
  }
}
