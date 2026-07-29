import 'package:flutter_test/flutter_test.dart';
import 'package:prioricash/domain/entities/expense.dart';
import 'package:prioricash/domain/value_objects/money.dart';

/// SW-17 — Expense entity.
///
/// Mirrors income_test.dart's structure. Two invariants matter here:
///
///  * the amount must be strictly positive — a zero or negative expense
///    is not a real spend and would misrepresent the balance calculation
///    (BalanceRepository.getTotalBalance sums this table directly).
///  * CategoryId member names are persisted verbatim as the id column of
///    categories, so renaming a member silently orphans existing foreign
///    keys — same convention as IncomeSourceId.
void main() {
  final spentAt = DateTime(2026, 7, 28);

  Expense build({
    String id = 'expense-1',
    CategoryId categoryId = CategoryId.food,
    Money? amount,
    String? instanceId,
    bool isReconciliation = false,
  }) => Expense(
    id: id,
    categoryId: categoryId,
    amount: amount ?? Money.fromMajor(40),
    spentAt: spentAt,
    instanceId: instanceId,
    isReconciliation: isReconciliation,
  );

  group('construction', () {
    test('holds the values it was given', () {
      final expense = build(instanceId: 'inst-breakfast-jul');

      expect(expense.id, 'expense-1');
      expect(expense.categoryId, CategoryId.food);
      expect(expense.amount, Money.fromMajor(40));
      expect(expense.spentAt, spentAt);
      expect(expense.instanceId, 'inst-breakfast-jul');
    });

    test('instanceId defaults to null — unlinked spending', () {
      expect(build().instanceId, isNull);
    });

    test('isReconciliation defaults to false', () {
      expect(build().isReconciliation, isFalse);
    });
  });

  group('validation', () {
    test('rejects an empty id', () {
      expect(() => build(id: ''), throwsArgumentError);
    });

    test('rejects a zero amount', () {
      expect(() => build(amount: Money.zero), throwsArgumentError);
    });

    test('rejects a negative amount', () {
      expect(() => build(amount: Money.fromMinor(-1)), throwsArgumentError);
    });

    test('accepts the smallest possible positive amount', () {
      expect(build(amount: Money.fromMinor(1)).amount.minorUnits, 1);
    });
  });

  group('identity', () {
    test('equality is the id, not the amount', () {
      final a = build(amount: Money.fromMajor(10));
      final b = build(amount: Money.fromMajor(999));

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different ids are different expenses', () {
      expect(build(id: 'expense-1'), isNot(equals(build(id: 'expense-2'))));
    });
  });

  group('CategoryId', () {
    test('wire names are stable — persisted as categories.id', () {
      expect(CategoryId.values.map((c) => c.name).toList(), [
        'food',
        'transport',
        'utilities',
        'health',
        'other',
      ]);
    });

    test('every category has a debug label for the database name column', () {
      for (final category in CategoryId.values) {
        expect(category.debugLabel, isNotEmpty);
      }
    });
  });
}
