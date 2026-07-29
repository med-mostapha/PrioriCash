import 'package:meta/meta.dart';
import 'package:prioricash/domain/value_objects/money.dart';

/// A fixed classification for a spent amount — SW-17.
///
/// Member names are persisted verbatim as `categories.id`, so renaming one
/// silently orphans the foreign key of every existing expense row. Same
/// convention as [IncomeSourceId] in income.dart.
///
/// [debugLabel] fills the `name` column for manual database inspection
/// only. What the user sees comes from `S.of(context)` — never from here.
enum CategoryId {
  food('Food'),
  transport('Transport'),
  utilities('Utilities'),
  health('Health'),
  other('Other');

  const CategoryId(this.debugLabel);

  final String debugLabel;
}

/// A single spent amount, optionally linked to the obligation instance it
/// counts against.
///
/// [instanceId] is the reconciliation link (SW-18): when set, this expense
/// is actual spending recorded against a specific estimated-lump
/// obligation instance (e.g. this month's Breakfast) — see the "Breakfast
/// budget" design decision in DOCS.md §4.1. When null, the expense is
/// unlinked spending with no obligation to reconcile against.
///
/// [isReconciliation] distinguishes a regular Quick Add Expense entry
/// (false, always, for SW-17) from a reconciliation-adjustment row that
/// SW-18's logic may create later. This entity never sets it true itself.
@immutable
class Expense {
  Expense({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.spentAt,
    this.instanceId,
    this.isReconciliation = false,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (amount.isZero || amount.isNegative) {
      throw ArgumentError.value(
        amount,
        'amount',
        'must be positive — a zero or negative expense is not a real '
            'spend and would misrepresent the balance calculation',
      );
    }
  }

  final String id;
  final CategoryId categoryId;
  final Money amount;
  final DateTime spentAt;
  final String? instanceId;
  final bool isReconciliation;

  /// Entity equality: identity is the id, not the amount.
  @override
  bool operator ==(Object other) => other is Expense && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Expense($id, $amount, ${categoryId.name})';
}
