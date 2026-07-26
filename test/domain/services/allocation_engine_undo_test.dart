import 'package:flutter_test/flutter_test.dart';
import 'package:prioricash/domain/entities/allocation.dart';
import 'package:prioricash/domain/services/allocation_engine.dart';
import 'package:prioricash/domain/value_objects/money.dart';

/// SW-7 — AllocationEngine.undo().
///
/// Exercises sprint acceptance criterion 4: any allocation performed by the
/// engine can be reversed, restoring the exact prior state.
///
/// undo() never deletes and never mutates in place — see SRS R10 and
/// AGENTS.md §1.4. It only decides WHAT should be reversed; applying that
/// to ObligationInstance.fundedAmount is the data layer's job, inside one
/// transaction (SW-11).
void main() {
  const engine = AllocationEngine();

  Allocation toInstance({
    String id = 'a-1',
    String incomeId = 'inc-1',
    int amountMinor = 50000,
    String instanceId = 'i-1',
    bool isReversed = false,
  }) {
    return Allocation(
      id: id,
      incomeId: incomeId,
      amount: Money.fromMinor(amountMinor),
      instanceId: instanceId,
      isReversed: isReversed,
    );
  }

  Allocation toGoal({
    String id = 'a-2',
    String incomeId = 'inc-1',
    int amountMinor = 20000,
    String goalId = 'goal-1',
    bool isReversed = false,
  }) {
    return Allocation(
      id: id,
      incomeId: incomeId,
      amount: Money.fromMinor(amountMinor),
      goalId: goalId,
      isReversed: isReversed,
    );
  }

  Allocation free({
    String id = 'a-3',
    String incomeId = 'inc-1',
    int amountMinor = 10000,
    bool isReversed = false,
  }) {
    return Allocation(
      id: id,
      incomeId: incomeId,
      amount: Money.fromMinor(amountMinor),
      isReversed: isReversed,
    );
  }

  group('basic reversal', () {
    test('reverses a single allocation', () {
      final a = toInstance();
      final result = engine.undo(incomeId: 'inc-1', allocations: [a]);

      expect(result, hasLength(1));
      expect(result.single.isReversed, isTrue);
    });

    test('the reversed copy keeps id, amount, and target unchanged', () {
      final a = toInstance(amountMinor: 75000, instanceId: 'i-42');
      final result = engine.undo(incomeId: 'inc-1', allocations: [a]);

      final reversed = result.single;
      expect(reversed.id, equals(a.id));
      expect(reversed.amount, equals(a.amount));
      expect(reversed.instanceId, equals(a.instanceId));
    });

    test(
      'reverses every allocation belonging to the income, of any target kind',
      () {
        final toInst = toInstance(id: 'a-1');
        final toG = toGoal(id: 'a-2');
        final toFree = free(id: 'a-3');

        final result = engine.undo(
          incomeId: 'inc-1',
          allocations: [toInst, toG, toFree],
        );

        expect(result, hasLength(3));
        expect(result.every((a) => a.isReversed), isTrue);
      },
    );
  });

  group('scoping by income', () {
    test('ignores allocations belonging to a different income', () {
      final mine = toInstance(id: 'a-1', incomeId: 'inc-1');
      final other = toInstance(id: 'a-2', incomeId: 'inc-2');

      final result = engine.undo(incomeId: 'inc-1', allocations: [mine, other]);

      expect(result, hasLength(1));
      expect(result.single.id, equals('a-1'));
    });

    test('an income with no matching allocations yields nothing', () {
      final other = toInstance(incomeId: 'inc-2');
      final result = engine.undo(incomeId: 'inc-1', allocations: [other]);
      expect(result, isEmpty);
    });

    test('an empty ledger yields nothing', () {
      final result = engine.undo(incomeId: 'inc-1', allocations: const []);
      expect(result, isEmpty);
    });
  });

  group('already-reversed rows are left alone', () {
    test('skips a row already reversed rather than double-reversing it', () {
      final already = toInstance(id: 'a-1', isReversed: true);
      final result = engine.undo(incomeId: 'inc-1', allocations: [already]);
      expect(result, isEmpty);
    });

    test('reverses only the not-yet-reversed rows in a mixed batch', () {
      final pending = toInstance(id: 'a-1');
      final already = toGoal(id: 'a-2', isReversed: true);

      final result = engine.undo(
        incomeId: 'inc-1',
        allocations: [pending, already],
      );

      expect(result, hasLength(1));
      expect(result.single.id, equals('a-1'));
    });
  });

  // -------------------------------------------------------------------
  // Acceptance criterion 4: exact restoration. Reversing everything must
  // sum back to zero — nothing gained, nothing lost.
  // -------------------------------------------------------------------
  group('exact restoration — acceptance criterion 4', () {
    test('the reversed amounts sum to exactly the original allocations', () {
      final allocations = [
        toInstance(id: 'a-1', amountMinor: 60000),
        toGoal(id: 'a-2', amountMinor: 25000),
        free(id: 'a-3', amountMinor: 15000),
      ];

      final reversed = engine.undo(incomeId: 'inc-1', allocations: allocations);

      final originalTotal = allocations.fold(
        Money.zero,
        (sum, a) => sum.add(a.amount),
      );
      final reversedTotal = reversed.fold(
        Money.zero,
        (sum, a) => sum.add(a.amount),
      );

      expect(reversedTotal, equals(originalTotal));
    });

    test('is a pure function — same input yields the same output', () {
      final allocations = [toInstance(), toGoal()];
      final first = engine.undo(incomeId: 'inc-1', allocations: allocations);
      final second = engine.undo(incomeId: 'inc-1', allocations: allocations);

      expect(first.map((a) => a.id), equals(second.map((a) => a.id)));
      expect(first.map((a) => a.amount), equals(second.map((a) => a.amount)));
    });

    test('does not mutate the allocations passed in', () {
      final a = toInstance();
      engine.undo(incomeId: 'inc-1', allocations: [a]);
      expect(a.isReversed, isFalse);
    });
  });
}
