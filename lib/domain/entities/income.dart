import 'package:meta/meta.dart';
import 'package:prioricash/domain/value_objects/money.dart';

/// Where a received amount came from — SRS R1.
///
/// Member names are persisted verbatim as `income_sources.id`, so renaming
/// one silently orphans the foreign key of every existing income row.
///
/// [debugLabel] fills the `name` column for manual database inspection
/// only. What the user sees comes from `S.of(context)` — never from here.
enum IncomeSourceId {
  grant('University grant'),
  family('Family support'),
  freelance('Freelance work'),
  gift('Gift'),
  other('Other');

  const IncomeSourceId(this.debugLabel);

  final String debugLabel;
}

/// A single received amount, linked to exactly one source. The system makes
/// no assumption about periodicity or expected amount — SRS R1.
@immutable
class Income {
  Income({
    required this.id,
    required this.sourceId,
    required this.amount,
    required this.receivedAt,
    this.note = '',
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (amount.isZero || amount.isNegative) {
      throw ArgumentError.value(
        amount,
        'amount',
        'must be positive — AllocationEngine.allocate() returns no '
            'allocations for zero or negative, leaving an income row that '
            'can never reach a fully allocated state (R19)',
      );
    }
  }

  final String id;
  final IncomeSourceId sourceId;
  final Money amount;
  final DateTime receivedAt;
  final String note;

  /// Entity equality: identity is the id, not the amount.
  @override
  bool operator ==(Object other) => other is Income && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Income($id, $amount from ${sourceId.name})';
}
