import 'package:flutter_test/flutter_test.dart';
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/entities/obligation_instance.dart';
import 'package:prioricash/domain/services/purchase_advisor.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/domain/value_objects/recurrence.dart';

/// SW-13 — PurchaseAdvisor.
///
/// Traces: R13 (safe / tight / breaksObligations verdicts), R14 (name the
/// specific instances that would become underfunded).
void main() {
  DateTime d(int year, int month, int day) => DateTime(year, month, day);
  final today = d(2026, 3, 15);

  const advisor = PurchaseAdvisor();

  Obligation obligation({
    required String id,
    Priority priority = Priority.high,
  }) {
    return Obligation(
      id: id,
      name: id,
      amount: Money.fromMinor(100000),
      recurrence: const Recurrence(RecurrenceType.monthly),
      priority: priority,
      startDate: d(2026, 1, 1),
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

  group('verdict — R13', () {
    test('safe when price does not exceed available', () {
      final verdict = advisor.evaluate(
        price: Money.fromMinor(50000),
        available: Money.fromMinor(100000),
        instances: const [],
        obligationsById: const {},
        today: today,
      );
      expect(verdict.result, equals(PurchaseResult.safe));
    });

    test('exactly at the available amount is tight, not safe', () {
      // R13: "safe" only below the 70% threshold; at 100% of available
      // the purchase leaves nothing for anything else, which is exactly
      // what "tight" is meant to flag.
      final verdict = advisor.evaluate(
        price: Money.fromMinor(100000),
        available: Money.fromMinor(100000),
        instances: const [],
        obligationsById: const {},
        today: today,
      );
      expect(verdict.result, equals(PurchaseResult.tight));
    });

    test('tight when price exceeds 70% of available but not all of it', () {
      final verdict = advisor.evaluate(
        price: Money.fromMinor(80000),
        available: Money.fromMinor(100000),
        instances: const [],
        obligationsById: const {},
        today: today,
      );
      expect(verdict.result, equals(PurchaseResult.tight));
    });

    test('exactly 70% of available is still safe, not tight', () {
      final verdict = advisor.evaluate(
        price: Money.fromMinor(70000),
        available: Money.fromMinor(100000),
        instances: const [],
        obligationsById: const {},
        today: today,
      );
      expect(verdict.result, equals(PurchaseResult.safe));
    });

    test('breaksObligations when price exceeds available', () {
      final verdict = advisor.evaluate(
        price: Money.fromMinor(150000),
        available: Money.fromMinor(100000),
        instances: const [],
        obligationsById: const {},
        today: today,
      );
      expect(verdict.result, equals(PurchaseResult.breaksObligations));
    });

    test('a negative available balance is always breaksObligations', () {
      final verdict = advisor.evaluate(
        price: Money.fromMinor(1000),
        available: Money.fromMinor(-50000),
        instances: const [],
        obligationsById: const {},
        today: today,
      );
      expect(verdict.result, equals(PurchaseResult.breaksObligations));
    });

    test('a zero price is always safe', () {
      final verdict = advisor.evaluate(
        price: Money.zero,
        available: Money.fromMinor(100000),
        instances: const [],
        obligationsById: const {},
        today: today,
      );
      expect(verdict.result, equals(PurchaseResult.safe));
    });
  });

  group('affected instances — R14', () {
    test('safe verdicts name no affected instances', () {
      final ob = obligation(id: 'ob-1');
      final inst = instance(
        id: 'i-1',
        obligationId: 'ob-1',
        dueDate: d(2026, 3, 20),
      );

      final verdict = advisor.evaluate(
        price: Money.fromMinor(20000),
        available: Money.fromMinor(100000),
        instances: [inst],
        obligationsById: {'ob-1': ob},
        today: today,
      );

      expect(verdict.affectedInstances, isEmpty);
    });

    test(
      'tight verdicts name no affected instances — nothing actually breaks yet',
      () {
        final ob = obligation(id: 'ob-1');
        final inst = instance(
          id: 'i-1',
          obligationId: 'ob-1',
          dueDate: d(2026, 3, 20),
        );

        final verdict = advisor.evaluate(
          price: Money.fromMinor(80000),
          available: Money.fromMinor(100000),
          instances: [inst],
          obligationsById: {'ob-1': ob},
          today: today,
        );

        expect(verdict.affectedInstances, isEmpty);
      },
    );

    test(
      'names the single instance that would go underfunded by the shortfall',
      () {
        final ob = obligation(id: 'ob-1');
        final soon = instance(
          id: 'i-soon',
          obligationId: 'ob-1',
          dueDate: d(2026, 3, 20),
        );
        final later = instance(
          id: 'i-later',
          obligationId: 'ob-1',
          dueDate: d(2026, 4, 10),
        );

        final verdict = advisor.evaluate(
          price: Money.fromMinor(250000),
          available: Money.fromMinor(200000),
          instances: [soon, later],
          obligationsById: {'ob-1': ob},
          today: today,
        );

        expect(verdict.result, equals(PurchaseResult.breaksObligations));
        expect(verdict.affectedInstances, hasLength(1));
        expect(verdict.affectedInstances.single.id, equals('i-later'));
      },
    );

    test('names multiple instances when the shortfall spans several', () {
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

      final verdict = advisor.evaluate(
        price: Money.fromMinor(450000),
        available: Money.fromMinor(300000),
        instances: [a, b, c],
        obligationsById: {'ob-1': ob},
        today: today,
      );

      expect(
        verdict.affectedInstances.map((i) => i.id),
        equals(['i-c', 'i-b']),
      );
    });

    test('only counts unfunded instances within the horizon set provided', () {
      final ob = obligation(id: 'ob-1');
      final funded = instance(
        id: 'i-funded',
        obligationId: 'ob-1',
        dueDate: d(2026, 3, 20),
        fundedMinor: 100000,
      );
      final unfunded = instance(
        id: 'i-unfunded',
        obligationId: 'ob-1',
        dueDate: d(2026, 4, 1),
      );

      final verdict = advisor.evaluate(
        price: Money.fromMinor(150000),
        available: Money.fromMinor(100000),
        instances: [funded, unfunded],
        obligationsById: {'ob-1': ob},
        today: today,
      );

      expect(verdict.affectedInstances, hasLength(1));
      expect(verdict.affectedInstances.single.id, equals('i-unfunded'));
    });

    test('the shortfall never names more instances than exist', () {
      final ob = obligation(id: 'ob-1');
      final inst = instance(
        id: 'i-1',
        obligationId: 'ob-1',
        dueDate: d(2026, 3, 20),
      );

      final verdict = advisor.evaluate(
        price: Money.fromMinor(999999),
        available: Money.fromMinor(1000),
        instances: [inst],
        obligationsById: {'ob-1': ob},
        today: today,
      );

      expect(verdict.affectedInstances, hasLength(1));
    });
  });

  group('is a pure function', () {
    test('the same input yields the same output', () {
      final ob = obligation(id: 'ob-1');
      final inst = instance(
        id: 'i-1',
        obligationId: 'ob-1',
        dueDate: d(2026, 3, 20),
      );

      final first = advisor.evaluate(
        price: Money.fromMinor(150000),
        available: Money.fromMinor(100000),
        instances: [inst],
        obligationsById: {'ob-1': ob},
        today: today,
      );
      final second = advisor.evaluate(
        price: Money.fromMinor(150000),
        available: Money.fromMinor(100000),
        instances: [inst],
        obligationsById: {'ob-1': ob},
        today: today,
      );

      expect(first.result, equals(second.result));
      expect(
        first.affectedInstances.map((i) => i.id),
        equals(second.affectedInstances.map((i) => i.id)),
      );
    });
  });
}
