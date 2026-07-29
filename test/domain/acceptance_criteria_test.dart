import 'package:flutter_test/flutter_test.dart';
import 'package:prioricash/domain/entities/allocation.dart';
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/entities/obligation_instance.dart';
import 'package:prioricash/domain/entities/savings_goal.dart';
import 'package:prioricash/domain/services/allocation_engine.dart';
import 'package:prioricash/domain/services/balance_calculator.dart';
import 'package:prioricash/domain/services/instance_generator.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/domain/value_objects/recurrence.dart';

/// SW-9 — Sprint 1 acceptance criteria (SRS §9.3 / BACKLOG.md).
///
/// These wire InstanceGenerator + AllocationEngine + BalanceCalculator
/// together the same way the data layer will in SW-11, and drive a
/// realistic scenario end to end. This file is never cut from the sprint.
///
/// Criterion 2 matters most: it is precisely the situation the app was
/// built for, and the first thing that breaks if the reservation query's
/// date range is wrong.
void main() {
  DateTime d(int year, int month, int day) => DateTime(year, month, day);

  const generator = InstanceGenerator();
  const engine = AllocationEngine();
  const calculator = BalanceCalculator();
  const horizonDays = 30;

  Obligation obligation({
    required String id,
    required int amountMinor,
    required DateTime startDate,
    Recurrence recurrence = const Recurrence(RecurrenceType.monthly),
    bool isEssential = true,
    Priority priority = Priority.high,
  }) {
    return Obligation(
      id: id,
      name: id,
      amount: Money.fromMinor(amountMinor),
      recurrence: recurrence,
      priority: priority,
      startDate: startDate,
      isEssential: isEssential,
    );
  }

  /// Applies a batch of allocations to their target instances, exactly as
  /// the data layer will inside one transaction. Kept here because SW-11
  /// does not exist yet — this is the contract SW-11 must satisfy.
  List<ObligationInstance> applyAllocations(
    List<ObligationInstance> instances,
    List<Allocation> allocations,
  ) {
    var result = instances;
    for (final allocation in allocations) {
      if (allocation.instanceId == null) continue;
      result = result.map((instance) {
        if (instance.id != allocation.instanceId) return instance;
        return instance.applyFunding(allocation.amount);
      }).toList();
    }
    return result;
  }

  group('criterion 1 — a month of irregular income, no manual correction', () {
    test(
      'three unpredictable incomes across a month fully fund every essential',
      () {
        final today = d(2026, 3, 1);
        final horizonEnd = today.add(const Duration(days: horizonDays));

        final wifi = obligation(
          id: 'ob-wifi',
          amountMinor: 50000,
          startDate: d(2026, 3, 5),
        );
        final subs = obligation(
          id: 'ob-subs',
          amountMinor: 30000,
          startDate: d(2026, 3, 12),
        );
        final breakfast = obligation(
          id: 'ob-breakfast',
          amountMinor: 220000,
          startDate: d(2026, 3, 1),
        );

        var instances = generator.generateAll(
          obligations: [wifi, subs, breakfast],
          horizonEnd: horizonEnd,
          existing: const [],
        );
        final obligationsById = {
          for (final ob in [wifi, subs, breakfast]) ob.id: ob,
        };

        final incomeAmounts = [
          Money.fromMinor(135000),
          Money.fromMinor(80000),
          Money.fromMinor(100000),
        ];

        for (var i = 0; i < incomeAmounts.length; i++) {
          final allocations = engine.allocate(
            incomeId: 'inc-$i',
            incomeAmount: incomeAmounts[i],
            instances: instances,
            obligationsById: obligationsById,
            goals: const [],
            today: today,
          );
          instances = applyAllocations(instances, allocations);
        }

        for (final instance in instances) {
          expect(
            instance.isFullyFunded,
            isTrue,
            reason: '${instance.id} should be fully funded by end of month',
          );
        }
      },
    );
  });

  group(
    'criterion 2 — overdue funded before future (the whole point of the app)',
    () {
      test(
        "two months of missed grant payments are cleared before this month's Wi-Fi",
        () {
          final today = d(2026, 3, 15);

          final wifi = obligation(
            id: 'ob-wifi',
            amountMinor: 50000,
            startDate: d(2026, 1, 5),
          );
          final obligationsById = {'ob-wifi': wifi};

          var instances = [
            ObligationInstance(
              id: 'i-jan',
              obligationId: 'ob-wifi',
              dueDate: d(2026, 1, 5),
              amount: Money.fromMinor(50000),
            ),
            ObligationInstance(
              id: 'i-feb',
              obligationId: 'ob-wifi',
              dueDate: d(2026, 2, 5),
              amount: Money.fromMinor(50000),
            ),
            ObligationInstance(
              id: 'i-mar',
              obligationId: 'ob-wifi',
              dueDate: d(2026, 3, 5),
              amount: Money.fromMinor(50000),
            ),
          ];

          expect(instances[0].isOverdue(today), isTrue);
          expect(instances[1].isOverdue(today), isTrue);
          expect(instances[2].isOverdue(today), isTrue);

          final allocations = engine.allocate(
            incomeId: 'inc-grant',
            incomeAmount: Money.fromMinor(100000),
            instances: instances,
            obligationsById: obligationsById,
            goals: const [],
            today: today,
          );

          expect(allocations, hasLength(2));
          expect(allocations[0].instanceId, equals('i-jan'));
          expect(allocations[1].instanceId, equals('i-feb'));

          instances = applyAllocations(instances, allocations);
          expect(instances[0].isFullyFunded, isTrue);
          expect(instances[1].isFullyFunded, isTrue);
          expect(instances[2].fundedAmount, equals(Money.zero));

          final second = engine.allocate(
            incomeId: 'inc-grant-2',
            incomeAmount: Money.fromMinor(50000),
            instances: instances,
            obligationsById: obligationsById,
            goals: const [],
            today: today,
          );
          expect(second.single.instanceId, equals('i-mar'));
        },
      );
    },
  );

  group('criterion 3 — available balance goes negative, unclamped', () {
    test(
      'accumulated overdue commitments exceeding total balance show as negative',
      () {
        final horizonEnd = d(
          2026,
          3,
          15,
        ).add(const Duration(days: horizonDays));

        final instances = [
          ObligationInstance(
            id: 'i-1',
            obligationId: 'ob-1',
            dueDate: d(2026, 1, 1),
            amount: Money.fromMinor(200000),
          ),
          ObligationInstance(
            id: 'i-2',
            obligationId: 'ob-1',
            dueDate: d(2026, 2, 1),
            amount: Money.fromMinor(200000),
          ),
          ObligationInstance(
            id: 'i-3',
            obligationId: 'ob-1',
            dueDate: d(2026, 2, 20),
            amount: Money.fromMinor(200000),
          ),
        ];

        final reserved = calculator.reservedAmount(
          instances: instances,
          horizonEnd: horizonEnd,
        );
        final available = calculator.availableBalance(
          total: Money.fromMinor(100000),
          reserved: reserved,
        );

        expect(available.isNegative, isTrue);
        expect(available, equals(Money.fromMinor(-500000)));
      },
    );
  });

  group('criterion 4 — undo restores the exact prior state', () {
    test(
      'reversing a full allocation batch returns every instance to its prior funding',
      () {
        final today = d(2026, 3, 15);

        final wifi = obligation(
          id: 'ob-wifi',
          amountMinor: 50000,
          startDate: d(2026, 3, 5),
        );
        final subs = obligation(
          id: 'ob-subs',
          amountMinor: 30000,
          startDate: d(2026, 3, 12),
        );
        final obligationsById = {'ob-wifi': wifi, 'ob-subs': subs};

        final before = [
          ObligationInstance(
            id: 'i-wifi',
            obligationId: 'ob-wifi',
            dueDate: d(2026, 3, 20),
            amount: Money.fromMinor(50000),
            fundedAmount: Money.fromMinor(10000),
          ),
          ObligationInstance(
            id: 'i-subs',
            obligationId: 'ob-subs',
            dueDate: d(2026, 3, 25),
            amount: Money.fromMinor(30000),
          ),
        ];
        final beforeSnapshot = {
          for (final i in before)
            i.id: (i.fundedAmount, i.computeStatus(today)),
        };

        final allocations = engine.allocate(
          incomeId: 'inc-1',
          incomeAmount: Money.fromMinor(60000),
          instances: before,
          obligationsById: obligationsById,
          goals: const [],
          today: today,
        );
        final afterFunding = applyAllocations(before, allocations);

        expect(
          afterFunding.firstWhere((i) => i.id == 'i-wifi').fundedAmount,
          isNot(equals(beforeSnapshot['i-wifi']!.$1)),
        );

        final reversedAllocations = engine.undo(
          incomeId: 'inc-1',
          allocations: allocations,
        );
        var restored = afterFunding;
        for (final reversed in reversedAllocations) {
          if (reversed.instanceId == null) continue;
          restored = restored.map((instance) {
            if (instance.id != reversed.instanceId) return instance;
            return instance.reverseFunding(reversed.amount);
          }).toList();
        }

        for (final instance in restored) {
          final snapshot = beforeSnapshot[instance.id]!;
          expect(
            instance.fundedAmount,
            equals(snapshot.$1),
            reason: '${instance.id} funded amount must match exactly',
          );
          expect(
            instance.computeStatus(today),
            equals(snapshot.$2),
            reason: '${instance.id} status must match exactly',
          );
        }
      },
    );

    test('undoing a savings-goal allocation is also exact', () {
      final goal = SavingsGoal(
        id: 'goal-1',
        targetAmount: Money.fromMinor(100000),
        currentAmount: Money.fromMinor(20000),
        priority: Priority.medium,
      );

      final allocations = engine.allocate(
        incomeId: 'inc-1',
        incomeAmount: Money.fromMinor(50000),
        instances: const [],
        obligationsById: const {},
        goals: [goal],
        today: d(2026, 3, 15),
      );

      expect(allocations, hasLength(1));
      expect(allocations.single.goalId, equals('goal-1'));

      final reversed = engine.undo(incomeId: 'inc-1', allocations: allocations);
      expect(reversed.single.isReversed, isTrue);
      expect(reversed.single.amount, equals(allocations.single.amount));
      expect(reversed.single.goalId, equals(allocations.single.goalId));
    });
  });

  // Criterion 5 is not directly testable at the domain layer (no network
  // client exists to disable). What IS verifiable here: the domain layer
  // performs its complete job using nothing but in-memory Dart objects and
  // zero async calls, which is the domain-layer precondition for the app
  // to work in airplane mode. Full verification happens on-device in SW-12.
  group(
    'criterion 5 — domain layer requires no I/O (necessary precondition)',
    () {
      test(
        'a full generate -> allocate -> balance -> undo cycle runs synchronously',
        () {
          final today = d(2026, 3, 15);
          final horizonEnd = today.add(const Duration(days: horizonDays));

          final ob = obligation(
            id: 'ob-1',
            amountMinor: 100000,
            startDate: d(2026, 3, 20),
          );

          final instances = generator.generate(
            obligation: ob,
            horizonEnd: horizonEnd,
            existing: const [],
          );
          final allocations = engine.allocate(
            incomeId: 'inc-1',
            incomeAmount: Money.fromMinor(100000),
            instances: instances,
            obligationsById: {'ob-1': ob},
            goals: const [],
            today: today,
          );
          final funded = applyAllocations(instances, allocations);
          final reserved = calculator.reservedAmount(
            instances: funded,
            horizonEnd: horizonEnd,
          );
          final available = calculator.availableBalance(
            total: Money.fromMinor(100000),
            reserved: reserved,
          );
          final undone = engine.undo(
            incomeId: 'inc-1',
            allocations: allocations,
          );
          expect(funded.every((i) => i.isFullyFunded), isTrue);
          // SW-18: fully funded but not yet paid still reserves the full
          // funded amount until actual spending against it is recorded —
          // no actualSpentByInstance data here means "nothing spent yet".
          expect(reserved, equals(Money.fromMinor(100000)));
          expect(available, equals(Money.zero));
          expect(undone.single.isReversed, isTrue);
        },
      );
    },
  );
}
