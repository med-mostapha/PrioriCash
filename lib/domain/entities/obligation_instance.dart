import 'package:meta/meta.dart';
import 'package:prioricash/domain/value_objects/money.dart';

/// Derived state of a single dated occurrence.
enum InstanceStatus { pending, partial, funded, paid, overdue }

@immutable
class ObligationInstance {
  ObligationInstance({
    required this.id,
    required this.obligationId,
    required this.dueDate,
    required this.amount,
    Money? fundedAmount,
    this.isPaid = false,
  }) : fundedAmount = fundedAmount ?? Money.zero {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (obligationId.isEmpty) {
      throw ArgumentError.value(
        obligationId,
        'obligationId',
        'must not be empty',
      );
    }
    if (amount.isZero || amount.isNegative) {
      throw ArgumentError.value(amount, 'amount', 'must be positive');
    }
    if (this.fundedAmount.isNegative) {
      throw ArgumentError.value(
        this.fundedAmount,
        'fundedAmount',
        'must not be negative',
      );
    }
  }

  final String id;
  final String obligationId;

  /// The day this occurrence falls due. Date-only.
  final DateTime dueDate;

  /// Total required for this occurrence.
  final Money amount;

  /// How much has been allocated so far. Never exceeds [amount].
  final Money fundedAmount;

  /// Set once the user confirms payment. Terminal.
  final bool isPaid;

  /// Still needed to cover this occurrence. Never negative.
  Money remaining() => amount.subtract(fundedAmount);

  bool get isFullyFunded => !fundedAmount.compareTo(amount).isNegative;

  /// True once the due date is in the past and funding is incomplete.
  bool isOverdue(DateTime today) =>
      !isPaid && !isFullyFunded && _daysBetween(today, dueDate) < 0;

  /// Signed day count to the due date. Negative once overdue.
  int daysUntilDue(DateTime today) => _daysBetween(today, dueDate);

  /// The single source of truth for status.
  InstanceStatus computeStatus(DateTime today) {
    if (isPaid) {
      return InstanceStatus.paid;
    }
    if (isFullyFunded) {
      return InstanceStatus.funded;
    }
    if (_daysBetween(today, dueDate) < 0) {
      return InstanceStatus.overdue;
    }
    if (fundedAmount.isZero) {
      return InstanceStatus.pending;
    }
    return InstanceStatus.partial;
  }

  /// Allocates [payment] towards this occurrence.
  ObligationInstance applyFunding(Money payment) {
    if (payment.isZero || payment.isNegative) {
      throw ArgumentError.value(payment, 'payment', 'must be positive');
    }
    if (isPaid) {
      throw StateError('Cannot fund an occurrence already marked paid');
    }
    final updated = fundedAmount.add(payment);
    if (updated.compareTo(amount) > 0) {
      throw ArgumentError.value(
        payment,
        'payment',
        'exceeds the remaining ${remaining()}',
      );
    }
    return _copyWith(fundedAmount: updated);
  }

  /// Reverses a previous allocation. Used by undo — SRS R10.
  ObligationInstance reverseFunding(Money payment) {
    if (payment.isZero || payment.isNegative) {
      throw ArgumentError.value(payment, 'payment', 'must be positive');
    }
    final updated = fundedAmount.subtract(payment);
    if (updated.isNegative) {
      throw ArgumentError.value(
        payment,
        'payment',
        'exceeds the funded $fundedAmount',
      );
    }
    return _copyWith(fundedAmount: updated);
  }

  /// Confirms the money actually left the account.
  ObligationInstance markPaid() {
    if (isPaid) {
      throw StateError('Already marked paid');
    }
    if (!isFullyFunded) {
      throw StateError('Cannot mark paid while ${remaining()} is unfunded');
    }
    return _copyWith(isPaid: true);
  }

  /// Entity equality: identity is the id, not the funding progress.
  @override
  bool operator ==(Object other) =>
      other is ObligationInstance && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ObligationInstance($id, due ${_format(dueDate)}, '
      '$fundedAmount of $amount${isPaid ? ', paid' : ''})';

  ObligationInstance _copyWith({Money? fundedAmount, bool? isPaid}) {
    return ObligationInstance(
      id: id,
      obligationId: obligationId,
      dueDate: dueDate,
      amount: amount,
      fundedAmount: fundedAmount ?? this.fundedAmount,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  /// Whole calendar days from [from] to [to], ignoring time and time zone.
  static int _daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  static String _format(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}'
      '-${value.day.toString().padLeft(2, '0')}';
}
