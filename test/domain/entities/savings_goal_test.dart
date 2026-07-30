import 'package:flutter_test/flutter_test.dart';
import 'package:prioricash/domain/entities/obligation.dart' show Priority;
import 'package:prioricash/domain/entities/savings_goal.dart';
import 'package:prioricash/domain/value_objects/money.dart';

/// SW-19 — SavingsGoal entity, expanded from its SW-6 minimal shape.
void main() {
  SavingsGoal build({
    String id = 'goal-1',
    String name = 'Emergency Fund',
    Money? targetAmount,
    Money? currentAmount,
    Priority priority = Priority.medium,
    bool isActive = true,
  }) => SavingsGoal(
    id: id,
    name: name,
    targetAmount: targetAmount ?? Money.fromMajor(1000),
    currentAmount: currentAmount ?? Money.zero,
    priority: priority,
    isActive: isActive,
  );

  group('construction', () {
    test('holds the values it was given', () {
      final goal = build(name: 'Vacation', targetAmount: Money.fromMajor(500));

      expect(goal.id, 'goal-1');
      expect(goal.name, 'Vacation');
      expect(goal.targetAmount, Money.fromMajor(500));
    });

    test('isActive defaults to true', () {
      expect(build().isActive, isTrue);
    });
  });

  group('validation', () {
    test('rejects an empty id', () {
      expect(() => build(id: ''), throwsArgumentError);
    });

    test('rejects an empty name', () {
      expect(() => build(name: ''), throwsArgumentError);
    });

    test('rejects a whitespace-only name', () {
      expect(() => build(name: '   '), throwsArgumentError);
    });

    test('rejects a zero target amount', () {
      expect(() => build(targetAmount: Money.zero), throwsArgumentError);
    });

    test('rejects a negative target amount', () {
      expect(
        () => build(targetAmount: Money.fromMinor(-1)),
        throwsArgumentError,
      );
    });

    test('rejects a negative current amount', () {
      expect(
        () => build(currentAmount: Money.fromMinor(-1)),
        throwsArgumentError,
      );
    });

    test('accepts a zero current amount — a brand-new goal', () {
      expect(build(currentAmount: Money.zero).currentAmount, Money.zero);
    });
  });

  group('remainingCapacity / isReached', () {
    test('capacity is the gap between target and current', () {
      final goal = build(
        targetAmount: Money.fromMinor(100000),
        currentAmount: Money.fromMinor(30000),
      );
      expect(goal.remainingCapacity(), equals(Money.fromMinor(70000)));
      expect(goal.isReached, isFalse);
    });

    test('reached exactly at target: zero capacity, isReached true', () {
      final goal = build(
        targetAmount: Money.fromMinor(100000),
        currentAmount: Money.fromMinor(100000),
      );
      expect(goal.remainingCapacity(), equals(Money.zero));
      expect(goal.isReached, isTrue);
    });

    test('capacity never goes negative past the target', () {
      final goal = build(
        targetAmount: Money.fromMinor(100000),
        currentAmount: Money.fromMinor(150000),
      );
      expect(goal.remainingCapacity(), equals(Money.zero));
    });
  });

  group('deactivate / copyWith', () {
    test('deactivate flips isActive without touching anything else', () {
      final goal = build();
      final deactivated = goal.deactivate();

      expect(deactivated.isActive, isFalse);
      expect(deactivated.name, goal.name);
      expect(deactivated.targetAmount, goal.targetAmount);
      expect(deactivated, equals(goal)); // same id, still "equal"
    });

    test('copyWith changes only the given fields', () {
      final goal = build(name: 'Old name');
      final renamed = goal.copyWith(name: 'New name');

      expect(renamed.name, 'New name');
      expect(renamed.targetAmount, goal.targetAmount);
      expect(renamed.id, goal.id);
    });
  });

  group('identity', () {
    test('equality is the id, not progress or name', () {
      final a = build(id: 'goal-1', name: 'A', currentAmount: Money.zero);
      final b = build(
        id: 'goal-1',
        name: 'B',
        currentAmount: Money.fromMajor(999),
      );
      expect(a, equals(b));
    });

    test('different ids are different goals', () {
      expect(build(id: 'goal-1'), isNot(equals(build(id: 'goal-2'))));
    });
  });
}
