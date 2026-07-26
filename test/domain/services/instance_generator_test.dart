import 'package:flutter_test/flutter_test.dart';
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/services/instance_generator.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/domain/value_objects/recurrence.dart';

/// SW-5 — InstanceGenerator.
///
/// The one property that matters most: generating twice for the same
/// obligation and horizon must never create duplicates. See SRS R15.
///
/// Pure domain service: existing instances are passed in, never fetched.
/// This keeps it testable with `dart test` alone, no database. See
/// AGENTS.md §2.2.
void main() {
  DateTime d(int year, int month, int day) => DateTime(year, month, day);

  Obligation build({
    String id = 'ob-1',
    DateTime? startDate,
    Recurrence recurrence = const Recurrence(RecurrenceType.monthly),
    bool isActive = true,
  }) {
    return Obligation(
      id: id,
      name: 'Wi-Fi',
      amount: Money.fromMinor(50000),
      recurrence: recurrence,
      priority: Priority.high,
      startDate: startDate ?? d(2026, 1, 5),
      isActive: isActive,
    );
  }

  const generator = InstanceGenerator();

  group('first generation', () {
    test('creates one instance per due date in the horizon', () {
      final ob = build(startDate: d(2026, 1, 5));
      final result = generator.generate(
        obligation: ob,
        horizonEnd: d(2026, 3, 31),
        existing: const [],
      );
      expect(result, hasLength(3));
      expect(
        result.map((i) => i.dueDate),
        equals([d(2026, 1, 5), d(2026, 2, 5), d(2026, 3, 5)]),
      );
    });

    test(
      'every created instance starts unfunded and linked to the obligation',
      () {
        final ob = build();
        final result = generator.generate(
          obligation: ob,
          horizonEnd: d(2026, 2, 28),
          existing: const [],
        );
        for (final instance in result) {
          expect(instance.obligationId, equals(ob.id));
          expect(instance.fundedAmount, equals(Money.zero));
          expect(instance.amount, equals(ob.amount));
          expect(instance.isPaid, isFalse);
        }
      },
    );

    test('instance ids are unique and deterministic for the same due date', () {
      final ob = build();
      final first = generator.generate(
        obligation: ob,
        horizonEnd: d(2026, 3, 31),
        existing: const [],
      );
      final regenerated = generator.generate(
        obligation: ob,
        horizonEnd: d(2026, 3, 31),
        existing: const [],
      );
      // Same obligation + due date must always produce the same id, so that
      // "existing" lookups work by id without a separate index.
      expect(first.map((i) => i.id), equals(regenerated.map((i) => i.id)));
    });

    test('an inactive obligation generates nothing', () {
      final ob = build(isActive: false);
      final result = generator.generate(
        obligation: ob,
        horizonEnd: d(2026, 12, 31),
        existing: const [],
      );
      expect(result, isEmpty);
    });

    test('an obligation starting after the horizon generates nothing', () {
      final ob = build(startDate: d(2026, 6, 1));
      final result = generator.generate(
        obligation: ob,
        horizonEnd: d(2026, 3, 31),
        existing: const [],
      );
      expect(result, isEmpty);
    });
  });

  // ---------------------------------------------------------------------
  // R15 — the whole point of this class.
  // ---------------------------------------------------------------------
  group('idempotency — running twice produces no duplicates', () {
    test('regenerating over the same horizon yields nothing new', () {
      final ob = build(startDate: d(2026, 1, 5));
      final firstRun = generator.generate(
        obligation: ob,
        horizonEnd: d(2026, 3, 31),
        existing: const [],
      );

      final secondRun = generator.generate(
        obligation: ob,
        horizonEnd: d(2026, 3, 31),
        existing: firstRun,
      );

      expect(secondRun, isEmpty);
    });

    test(
      'regenerating after the horizon extends only creates the new ones',
      () {
        final ob = build(startDate: d(2026, 1, 5));
        final firstRun = generator.generate(
          obligation: ob,
          horizonEnd: d(2026, 2, 28),
          existing: const [],
        );
        expect(firstRun, hasLength(2)); // Jan 5, Feb 5

        final secondRun = generator.generate(
          obligation: ob,
          horizonEnd: d(2026, 4, 30),
          existing: firstRun,
        );

        expect(
          secondRun.map((i) => i.dueDate),
          equals([d(2026, 3, 5), d(2026, 4, 5)]),
        );
      },
    );

    test('running three times in a row never duplicates', () {
      final ob = build(startDate: d(2026, 1, 5));
      var all = generator.generate(
        obligation: ob,
        horizonEnd: d(2026, 6, 30),
        existing: const [],
      );

      for (var i = 0; i < 2; i++) {
        final next = generator.generate(
          obligation: ob,
          horizonEnd: d(2026, 6, 30),
          existing: all,
        );
        expect(next, isEmpty);
        all = [...all, ...next];
      }

      expect(all.map((i) => i.dueDate).toSet(), hasLength(6));
    });

    test('does not touch or return existing instances, funded or not', () {
      final ob = build(startDate: d(2026, 1, 5));
      final firstRun = generator.generate(
        obligation: ob,
        horizonEnd: d(2026, 2, 28),
        existing: const [],
      );
      final partiallyFunded = firstRun.first.applyFunding(
        Money.fromMinor(20000),
      );

      final secondRun = generator.generate(
        obligation: ob,
        horizonEnd: d(2026, 3, 31),
        existing: [partiallyFunded, firstRun.last],
      );

      // Only March is genuinely new; January/February must not reappear,
      // and the funded January instance must not be reset or duplicated.
      expect(secondRun, hasLength(1));
      expect(secondRun.single.dueDate, equals(d(2026, 3, 5)));
    });

    test(
      'existing instances from a different obligation do not block generation',
      () {
        final obA = build(id: 'ob-a', startDate: d(2026, 1, 5));
        final obB = build(id: 'ob-b', startDate: d(2026, 1, 5));

        final existingForA = generator.generate(
          obligation: obA,
          horizonEnd: d(2026, 1, 31),
          existing: const [],
        );

        // Same due date, different obligation — must still generate for B.
        final resultForB = generator.generate(
          obligation: obB,
          horizonEnd: d(2026, 1, 31),
          existing: existingForA,
        );

        expect(resultForB, hasLength(1));
        expect(resultForB.single.obligationId, equals('ob-b'));
      },
    );
  });

  group('batch generation across many obligations', () {
    test('generateAll aggregates results for every active obligation', () {
      final obligations = [
        build(id: 'ob-1', startDate: d(2026, 1, 5)),
        build(id: 'ob-2', startDate: d(2026, 1, 10)),
        build(id: 'ob-3', startDate: d(2026, 6, 1)), // outside horizon
        build(id: 'ob-4', startDate: d(2026, 1, 1), isActive: false),
      ];

      final result = generator.generateAll(
        obligations: obligations,
        horizonEnd: d(2026, 1, 31),
        existing: const [],
      );

      expect(
        result.map((i) => i.obligationId).toSet(),
        equals({'ob-1', 'ob-2'}),
      );
    });

    test('generateAll is idempotent across the whole set', () {
      final obligations = [
        build(id: 'ob-1', startDate: d(2026, 1, 5)),
        build(id: 'ob-2', startDate: d(2026, 1, 10)),
      ];

      final firstRun = generator.generateAll(
        obligations: obligations,
        horizonEnd: d(2026, 3, 31),
        existing: const [],
      );

      final secondRun = generator.generateAll(
        obligations: obligations,
        horizonEnd: d(2026, 3, 31),
        existing: firstRun,
      );

      expect(secondRun, isEmpty);
    });
  });
}
