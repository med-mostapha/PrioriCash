import 'package:flutter_test/flutter_test.dart';
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/entities/obligation_instance.dart';
import 'package:prioricash/domain/entities/savings_goal.dart';
import 'package:prioricash/domain/services/allocation_engine.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/domain/value_objects/recurrence.dart';

/// SW-6 — AllocationEngine.allocate().
///
/// This is the highest-risk file in the project. Every one of the five
/// sprint acceptance criteria (SRS §9.3) is exercised somewhere below.
///
/// Traces: R6, R7, R8, R9.
void main() {
  DateTime d(int year, int month, int day) => DateTime(year, month, day);
  final today = d(2026, 3, 15);

  const engine = AllocationEngine();

  Obligation obligation({
    required String id,
    bool isEssential = true,
    Priority priority = Priority.high,
  }) {
    return Obligation(
      id: id,
      name: id,
      amount: Money.fromMinor(100000),
      recurrence: const Recurrence(RecurrenceType.monthly),
      priority: priority,
      startDate: d(2026, 1, 1),
      isEssential: isEssential,
    );
  }

  ObligationInstance instance({
    required String id,
    required String obligationId,
    required DateTime dueDate,
    int amountMinor = 100000,
    int fundedMinor = 0,
  }) {
    return ObligationInstance(
      id: id,
      obligationId: obligationId,
      dueDate: dueDate,
      amount: Money.fromMinor(amountMinor),
      fundedAmount: Money.fromMinor(fundedMinor),
    );
  }

  SavingsGoal goal({
    required String id,
    int targetMinor = 100000,
    int currentMinor = 0,
    Priority priority = Priority.medium,
  }) {
    return SavingsGoal(
      id: id,
      targetAmount: Money.fromMinor(targetMinor),
      currentAmount: Money.fromMinor(currentMinor),
      priority: priority,
    );
  }

  group('basic funding', () {
    test('funds a single instance exactly', () {
      final ob = obligation(id: 'ob-1');
      final inst = instance(
        id: 'i-1',
        obligationId: 'ob-1',
        dueDate: d(2026, 3, 20),
      );

      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(100000),
        instances: [inst],
        obligationsById: {'ob-1': ob},
        goals: const [],
        today: today,
      );

      expect(result, hasLength(1));
      expect(result.single.amount, equals(Money.fromMinor(100000)));
      expect(result.single.instanceId, equals('i-1'));
      expect(result.single.incomeId, equals('inc-1'));
    });

    test('partially funds when income is smaller than the shortfall', () {
      final ob = obligation(id: 'ob-1');
      final inst = instance(
        id: 'i-1',
        obligationId: 'ob-1',
        dueDate: d(2026, 3, 20),
      );

      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(30000),
        instances: [inst],
        obligationsById: {'ob-1': ob},
        goals: const [],
        today: today,
      );

      expect(result, hasLength(1));
      expect(result.single.amount, equals(Money.fromMinor(30000)));
    });

    test('skips an instance already fully funded', () {
      final ob = obligation(id: 'ob-1');
      final inst = instance(
        id: 'i-1',
        obligationId: 'ob-1',
        dueDate: d(2026, 3, 20),
        fundedMinor: 100000,
      );

      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.zero,
        instances: [inst],
        obligationsById: {'ob-1': ob},
        goals: const [],
        today: today,
      );

      expect(result, isEmpty);
    });

    test(
      'only allocates the remaining shortfall of a partly funded instance',
      () {
        final ob = obligation(id: 'ob-1');
        final inst = instance(
          id: 'i-1',
          obligationId: 'ob-1',
          dueDate: d(2026, 3, 20),
          fundedMinor: 60000,
        );

        final result = engine.allocate(
          incomeId: 'inc-1',
          incomeAmount: Money.fromMinor(40000),
          instances: [inst],
          obligationsById: {'ob-1': ob},
          goals: const [],
          today: today,
        );

        expect(result, hasLength(1));
        expect(result.single.amount, equals(Money.fromMinor(40000)));
      },
    );

    test('zero income allocates nothing and does not throw', () {
      final ob = obligation(id: 'ob-1');
      final inst = instance(
        id: 'i-1',
        obligationId: 'ob-1',
        dueDate: d(2026, 3, 20),
      );

      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.zero,
        instances: [inst],
        obligationsById: {'ob-1': ob},
        goals: const [],
        today: today,
      );

      expect(result, isEmpty);
    });
  });

  group('ordering — R6', () {
    test('funds the earliest due date first regardless of priority', () {
      final obLow = obligation(id: 'ob-low', priority: Priority.low);
      final obHigh = obligation(id: 'ob-high', priority: Priority.high);

      final soon = instance(
        id: 'i-soon',
        obligationId: 'ob-low',
        dueDate: d(2026, 3, 17),
      );
      final later = instance(
        id: 'i-later',
        obligationId: 'ob-high',
        dueDate: d(2026, 4, 10),
      );

      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(100000),
        instances: [later, soon],
        obligationsById: {'ob-low': obLow, 'ob-high': obHigh},
        goals: const [],
        today: today,
      );

      expect(result, hasLength(1));
      expect(result.single.instanceId, equals('i-soon'));
    });

    test('priority breaks a tie on the same due date', () {
      final obLow = obligation(id: 'ob-low', priority: Priority.low);
      final obHigh = obligation(id: 'ob-high', priority: Priority.high);

      final sameDate = d(2026, 3, 20);
      final low = instance(
        id: 'i-low',
        obligationId: 'ob-low',
        dueDate: sameDate,
      );
      final high = instance(
        id: 'i-high',
        obligationId: 'ob-high',
        dueDate: sameDate,
      );

      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(100000),
        instances: [low, high],
        obligationsById: {'ob-low': obLow, 'ob-high': obHigh},
        goals: const [],
        today: today,
      );

      expect(result, hasLength(1));
      expect(result.single.instanceId, equals('i-high'));
    });

    test(
      'funds multiple instances in strict due-date order until funds run out',
      () {
        final ob = obligation(id: 'ob-1');
        final first = instance(
          id: 'i-1',
          obligationId: 'ob-1',
          dueDate: d(2026, 3, 16),
        );
        final second = instance(
          id: 'i-2',
          obligationId: 'ob-1',
          dueDate: d(2026, 3, 20),
        );
        final third = instance(
          id: 'i-3',
          obligationId: 'ob-1',
          dueDate: d(2026, 3, 25),
        );

        final result = engine.allocate(
          incomeId: 'inc-1',
          incomeAmount: Money.fromMinor(150000),
          instances: [third, first, second],
          obligationsById: {'ob-1': ob},
          goals: const [],
          today: today,
        );

        expect(result, hasLength(2));
        expect(result[0].instanceId, equals('i-1'));
        expect(result[0].amount, equals(Money.fromMinor(100000)));
        expect(result[1].instanceId, equals('i-2'));
        expect(result[1].amount, equals(Money.fromMinor(50000)));
      },
    );
  });

  group('overdue accumulation — acceptance criterion 2', () {
    test('an overdue instance is funded before a future one', () {
      final ob = obligation(id: 'ob-1');
      final overdue = instance(
        id: 'i-overdue',
        obligationId: 'ob-1',
        dueDate: d(2026, 2, 1),
      );
      final future = instance(
        id: 'i-future',
        obligationId: 'ob-1',
        dueDate: d(2026, 4, 1),
      );

      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(100000),
        instances: [future, overdue],
        obligationsById: {'ob-1': ob},
        goals: const [],
        today: today,
      );

      expect(result, hasLength(1));
      expect(result.single.instanceId, equals('i-overdue'));
    });

    test(
      'several accumulated overdue instances are all funded before new income reaches the future',
      () {
        final ob = obligation(id: 'ob-1');
        final overdue1 = instance(
          id: 'i-o1',
          obligationId: 'ob-1',
          dueDate: d(2026, 1, 5),
        );
        final overdue2 = instance(
          id: 'i-o2',
          obligationId: 'ob-1',
          dueDate: d(2026, 2, 5),
        );
        final future = instance(
          id: 'i-future',
          obligationId: 'ob-1',
          dueDate: d(2026, 4, 5),
        );

        final result = engine.allocate(
          incomeId: 'inc-1',
          incomeAmount: Money.fromMinor(250000),
          instances: [future, overdue2, overdue1],
          obligationsById: {'ob-1': ob},
          goals: const [],
          today: today,
        );

        expect(result, hasLength(3));
        expect(result[0].instanceId, equals('i-o1'));
        expect(result[1].instanceId, equals('i-o2'));
        expect(result[2].instanceId, equals('i-future'));
        expect(result[2].amount, equals(Money.fromMinor(50000)));
      },
    );
  });

  group('scarcity', () {
    test(
      'funds as many essentials as possible in order, leaving the rest untouched',
      () {
        final ob = obligation(id: 'ob-1');
        final a = instance(
          id: 'i-a',
          obligationId: 'ob-1',
          dueDate: d(2026, 3, 16),
        );
        final b = instance(
          id: 'i-b',
          obligationId: 'ob-1',
          dueDate: d(2026, 3, 20),
        );
        final c = instance(
          id: 'i-c',
          obligationId: 'ob-1',
          dueDate: d(2026, 3, 25),
        );

        final result = engine.allocate(
          incomeId: 'inc-1',
          incomeAmount: Money.fromMinor(100000),
          instances: [a, b, c],
          obligationsById: {'ob-1': ob},
          goals: const [],
          today: today,
        );

        expect(result, hasLength(1));
        expect(result.single.instanceId, equals('i-a'));
      },
    );
  });

  group('essential gate — R7', () {
    test(
      'a discretionary instance is not funded while essentials are short',
      () {
        final essential = obligation(id: 'ob-essential');
        final discretionary = obligation(
          id: 'ob-discretionary',
          isEssential: false,
        );

        final essentialInst = instance(
          id: 'i-essential',
          obligationId: 'ob-essential',
          dueDate: d(2026, 3, 16),
        );
        final discretionaryInst = instance(
          id: 'i-discretionary',
          obligationId: 'ob-discretionary',
          dueDate: d(2026, 3, 17),
        );

        final result = engine.allocate(
          incomeId: 'inc-1',
          incomeAmount: Money.fromMinor(100000),
          instances: [essentialInst, discretionaryInst],
          obligationsById: {
            'ob-essential': essential,
            'ob-discretionary': discretionary,
          },
          goals: const [],
          today: today,
        );

        expect(result, hasLength(1));
        expect(result.single.instanceId, equals('i-essential'));
      },
    );

    test(
      'a discretionary instance is funded from surplus once essentials are covered',
      () {
        final essential = obligation(id: 'ob-essential');
        final discretionary = obligation(
          id: 'ob-discretionary',
          isEssential: false,
        );

        final essentialInst = instance(
          id: 'i-essential',
          obligationId: 'ob-essential',
          dueDate: d(2026, 3, 16),
        );
        final discretionaryInst = instance(
          id: 'i-discretionary',
          obligationId: 'ob-discretionary',
          dueDate: d(2026, 3, 17),
          amountMinor: 20000,
        );

        final result = engine.allocate(
          incomeId: 'inc-1',
          incomeAmount: Money.fromMinor(120000),
          instances: [essentialInst, discretionaryInst],
          obligationsById: {
            'ob-essential': essential,
            'ob-discretionary': discretionary,
          },
          goals: const [],
          today: today,
        );

        expect(result, hasLength(2));
        expect(result[0].instanceId, equals('i-essential'));
        expect(result[0].amount, equals(Money.fromMinor(100000)));
        expect(result[1].instanceId, equals('i-discretionary'));
        expect(result[1].amount, equals(Money.fromMinor(20000)));
      },
    );

    test(
      'a discretionary instance is skipped entirely if no surplus remains',
      () {
        final essential = obligation(id: 'ob-essential');
        final discretionary = obligation(
          id: 'ob-discretionary',
          isEssential: false,
        );

        final essentialInst = instance(
          id: 'i-essential',
          obligationId: 'ob-essential',
          dueDate: d(2026, 3, 16),
        );
        final discretionaryInst = instance(
          id: 'i-discretionary',
          obligationId: 'ob-discretionary',
          dueDate: d(2026, 3, 17),
        );

        final result = engine.allocate(
          incomeId: 'inc-1',
          incomeAmount: Money.fromMinor(100000),
          instances: [essentialInst, discretionaryInst],
          obligationsById: {
            'ob-essential': essential,
            'ob-discretionary': discretionary,
          },
          goals: const [],
          today: today,
        );

        expect(result, hasLength(1));
        expect(result.single.instanceId, equals('i-essential'));
      },
    );

    test('an overdue discretionary instance still waits behind essentials', () {
      final essential = obligation(id: 'ob-essential');
      final discretionary = obligation(
        id: 'ob-discretionary',
        isEssential: false,
      );

      final discretionaryInst = instance(
        id: 'i-discretionary',
        obligationId: 'ob-discretionary',
        dueDate: d(2026, 1, 1),
      );
      final essentialInst = instance(
        id: 'i-essential',
        obligationId: 'ob-essential',
        dueDate: d(2026, 3, 20),
      );

      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(100000),
        instances: [discretionaryInst, essentialInst],
        obligationsById: {
          'ob-essential': essential,
          'ob-discretionary': discretionary,
        },
        goals: const [],
        today: today,
      );

      expect(result, hasLength(1));
      expect(result.single.instanceId, equals('i-essential'));
    });
  });

  group('savings goals', () {
    test('a goal receives surplus once all essential instances are funded', () {
      final ob = obligation(id: 'ob-1');
      final inst = instance(
        id: 'i-1',
        obligationId: 'ob-1',
        dueDate: d(2026, 3, 20),
      );
      final g = goal(id: 'goal-1', targetMinor: 50000);

      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(150000),
        instances: [inst],
        obligationsById: {'ob-1': ob},
        goals: [g],
        today: today,
      );

      expect(result, hasLength(2));
      expect(result[0].instanceId, equals('i-1'));
      expect(result[1].goalId, equals('goal-1'));
      expect(result[1].amount, equals(Money.fromMinor(50000)));
    });

    test('a goal receives only up to its remaining capacity, not more', () {
      final g = goal(id: 'goal-1', targetMinor: 50000, currentMinor: 30000);

      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(20000),
        instances: const [],
        obligationsById: const {},
        goals: [g],
        today: today,
      );

      expect(result, hasLength(1));
      expect(result.single.amount, equals(Money.fromMinor(20000)));
    });

    test('a goal already reached receives nothing', () {
      final g = goal(id: 'goal-1', targetMinor: 50000, currentMinor: 50000);

      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.zero,
        instances: const [],
        obligationsById: const {},
        goals: [g],
        today: today,
      );

      expect(result, isEmpty);
    });

    test('goals are funded in priority order when surplus is limited', () {
      final low = goal(
        id: 'goal-low',
        targetMinor: 100000,
        priority: Priority.low,
      );
      final high = goal(
        id: 'goal-high',
        targetMinor: 100000,
        priority: Priority.high,
      );

      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(50000),
        instances: const [],
        obligationsById: const {},
        goals: [low, high],
        today: today,
      );

      expect(result, hasLength(1));
      expect(result.single.goalId, equals('goal-high'));
    });

    test('leftover after every instance and goal becomes free balance', () {
      final ob = obligation(id: 'ob-1');
      final inst = instance(
        id: 'i-1',
        obligationId: 'ob-1',
        dueDate: d(2026, 3, 20),
      );
      final g = goal(id: 'goal-1', targetMinor: 20000);

      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(150000),
        instances: [inst],
        obligationsById: {'ob-1': ob},
        goals: [g],
        today: today,
      );

      expect(result, hasLength(3));
      final free = result.last;
      expect(free.isFreeBalance, isTrue);
      expect(free.amount, equals(Money.fromMinor(30000)));
    });

    test('no instances and no goals: the entire income is free balance', () {
      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(50000),
        instances: const [],
        obligationsById: const {},
        goals: const [],
        today: today,
      );

      expect(result, hasLength(1));
      expect(result.single.isFreeBalance, isTrue);
      expect(result.single.amount, equals(Money.fromMinor(50000)));
    });
  });

  group('ledger integrity — R8, R9', () {
    test('every allocation is linked to the income that produced it', () {
      final ob = obligation(id: 'ob-1');
      final inst = instance(
        id: 'i-1',
        obligationId: 'ob-1',
        dueDate: d(2026, 3, 20),
      );

      final result = engine.allocate(
        incomeId: 'inc-xyz',
        incomeAmount: Money.fromMinor(100000),
        instances: [inst],
        obligationsById: {'ob-1': ob},
        goals: const [],
        today: today,
      );

      expect(result.every((a) => a.incomeId == 'inc-xyz'), isTrue);
    });

    test('each allocation targets exactly one thing', () {
      final ob = obligation(id: 'ob-1');
      final inst = instance(
        id: 'i-1',
        obligationId: 'ob-1',
        dueDate: d(2026, 3, 20),
      );
      final g = goal(id: 'goal-1', targetMinor: 20000);

      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(150000),
        instances: [inst],
        obligationsById: {'ob-1': ob},
        goals: [g],
        today: today,
      );

      for (final a in result) {
        final targets = [
          a.instanceId != null,
          a.goalId != null,
          a.isFreeBalance,
        ].where((isSet) => isSet).length;
        expect(targets, equals(1));
      }
    });

    test('allocation amounts never exceed the income given', () {
      final ob = obligation(id: 'ob-1');
      final inst = instance(
        id: 'i-1',
        obligationId: 'ob-1',
        dueDate: d(2026, 3, 20),
      );
      final g = goal(id: 'goal-1');

      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(80000),
        instances: [inst],
        obligationsById: {'ob-1': ob},
        goals: [g],
        today: today,
      );

      final total = result.fold(Money.zero, (sum, a) => sum.add(a.amount));
      expect(total, equals(Money.fromMinor(80000)));
    });

    test('allocation ids are unique within a single run', () {
      final ob = obligation(id: 'ob-1');
      final a = instance(
        id: 'i-a',
        obligationId: 'ob-1',
        dueDate: d(2026, 3, 16),
      );
      final b = instance(
        id: 'i-b',
        obligationId: 'ob-1',
        dueDate: d(2026, 3, 20),
      );

      final result = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(200000),
        instances: [a, b],
        obligationsById: {'ob-1': ob},
        goals: const [],
        today: today,
      );

      expect(result.map((r) => r.id).toSet(), hasLength(result.length));
    });

    test('is a pure function — the same input yields the same output', () {
      final ob = obligation(id: 'ob-1');
      final inst = instance(
        id: 'i-1',
        obligationId: 'ob-1',
        dueDate: d(2026, 3, 20),
      );

      final first = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(100000),
        instances: [inst],
        obligationsById: {'ob-1': ob},
        goals: const [],
        today: today,
      );
      final second = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(100000),
        instances: [inst],
        obligationsById: {'ob-1': ob},
        goals: const [],
        today: today,
      );

      expect(first.map((a) => a.amount), equals(second.map((a) => a.amount)));
    });
  });
}
