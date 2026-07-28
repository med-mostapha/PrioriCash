import 'package:flutter_test/flutter_test.dart';
import 'package:prioricash/domain/entities/income.dart';
import 'package:prioricash/domain/value_objects/money.dart';

/// SW-15a — Income entity.
///
/// An income is the only thing that ever enters the system as new money.
/// Two invariants matter here:
///
///  * the amount must be strictly positive — AllocationEngine.allocate()
///    returns const [] for zero or negative, which would persist an income
///    row with no allocations at all and break R19 (every income must
///    reach a fully allocated state).
///  * IncomeSourceId member names are persisted verbatim as the id column
///    of income_sources, so renaming a member silently orphans existing
///    foreign keys.
void main() {
  final receivedAt = DateTime(2026, 7, 28);

  Income build({
    String id = 'income-1',
    IncomeSourceId sourceId = IncomeSourceId.grant,
    Money? amount,
    String note = '',
  }) => Income(
    id: id,
    sourceId: sourceId,
    amount: amount ?? Money.fromMajor(1350),
    receivedAt: receivedAt,
    note: note,
  );

  group('construction', () {
    test('holds the values it was given', () {
      final income = build(note: 'university grant, finally');

      expect(income.id, 'income-1');
      expect(income.sourceId, IncomeSourceId.grant);
      expect(income.amount, Money.fromMajor(1350));
      expect(income.receivedAt, receivedAt);
      expect(income.note, 'university grant, finally');
    });

    test('note defaults to empty', () {
      expect(build().note, isEmpty);
    });
  });

  group('validation', () {
    test('rejects an empty id', () {
      expect(() => build(id: ''), throwsArgumentError);
    });

    test('rejects a zero amount — it would allocate to nothing (R19)', () {
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
      final a = build(amount: Money.fromMajor(100));
      final b = build(amount: Money.fromMajor(999));

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different ids are different incomes', () {
      expect(build(id: 'income-1'), isNot(equals(build(id: 'income-2'))));
    });
  });

  group('IncomeSourceId', () {
    test('wire names are stable — persisted as income_sources.id', () {
      expect(IncomeSourceId.values.map((s) => s.name).toList(), [
        'grant',
        'family',
        'freelance',
        'gift',
        'other',
      ]);
    });

    test('every source has a debug label for the database name column', () {
      for (final source in IncomeSourceId.values) {
        expect(source.debugLabel, isNotEmpty);
      }
    });
  });
}
