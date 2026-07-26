import 'package:flutter_test/flutter_test.dart';
import 'package:prioricash/domain/value_objects/recurrence.dart';

/// SW-3 — Recurrence.occurrencesBetween()
///
/// Dates look simple and are not. Every test below pins a decision that is
/// expensive to get wrong and invisible when it is wrong.
///
/// Scope: daily, weekly, monthly. `yearly` and `custom` are deferred to
/// Sprint 2 per the risk register in BACKLOG.md.
void main() {
  // Helper: dates are date-only. Time of day is never part of a due date.
  DateTime d(int year, int month, int day) => DateTime(year, month, day);

  // ---------------------------------------------------------------------
  // Construction and validation
  // ---------------------------------------------------------------------
  group('construction', () {
    test('interval defaults to 1', () {
      expect(const Recurrence(RecurrenceType.monthly).interval, equals(1));
    });

    test('rejects a zero interval', () {
      expect(
        () => const Recurrence(RecurrenceType.daily, interval: 0).occurrencesBetween(
          anchor: d(2026, 1, 1),
          from: d(2026, 1, 1),
          to: d(2026, 1, 5),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative interval', () {
      expect(
        () => const Recurrence(RecurrenceType.daily, interval: -2).occurrencesBetween(
          anchor: d(2026, 1, 1),
          from: d(2026, 1, 1),
          to: d(2026, 1, 5),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a range that runs backwards', () {
      expect(
        () => const Recurrence(RecurrenceType.daily).occurrencesBetween(
          anchor: d(2026, 1, 1),
          from: d(2026, 1, 10),
          to: d(2026, 1, 5),
        ),
        throwsArgumentError,
      );
    });
  });

  // ---------------------------------------------------------------------
  // Daily — the breakfast case
  // ---------------------------------------------------------------------
  group('daily', () {
    test('every day, both range ends inclusive', () {
      final result = const Recurrence(RecurrenceType.daily).occurrencesBetween(
        anchor: d(2026, 1, 1),
        from: d(2026, 1, 1),
        to: d(2026, 1, 10),
      );
      expect(result, hasLength(10));
      expect(result.first, equals(d(2026, 1, 1)));
      expect(result.last, equals(d(2026, 1, 10)));
    });

    test('every third day', () {
      final result = const Recurrence(RecurrenceType.daily, interval: 3)
          .occurrencesBetween(
            anchor: d(2026, 1, 1),
            from: d(2026, 1, 1),
            to: d(2026, 1, 10),
          );
      expect(
        result,
        equals([d(2026, 1, 1), d(2026, 1, 4), d(2026, 1, 7), d(2026, 1, 10)]),
      );
    });

    test('crosses a month boundary', () {
      final result = const Recurrence(RecurrenceType.daily).occurrencesBetween(
        anchor: d(2026, 1, 30),
        from: d(2026, 1, 30),
        to: d(2026, 2, 2),
      );
      expect(
        result,
        equals([d(2026, 1, 30), d(2026, 1, 31), d(2026, 2, 1), d(2026, 2, 2)]),
      );
    });
  });

  // ---------------------------------------------------------------------
  // Weekly — the wifi case
  // ---------------------------------------------------------------------
  group('weekly', () {
    test('every 7 days', () {
      final result = const Recurrence(RecurrenceType.weekly).occurrencesBetween(
        anchor: d(2026, 1, 5),
        from: d(2026, 1, 1),
        to: d(2026, 2, 1),
      );
      expect(
        result,
        equals([d(2026, 1, 5), d(2026, 1, 12), d(2026, 1, 19), d(2026, 1, 26)]),
      );
    });

    test('keeps the same weekday', () {
      final result = const Recurrence(RecurrenceType.weekly).occurrencesBetween(
        anchor: d(2026, 1, 5),
        from: d(2026, 1, 1),
        to: d(2026, 3, 1),
      );
      final weekdays = result.map((o) => o.weekday).toSet();
      expect(weekdays, hasLength(1));
    });

    test('every two weeks', () {
      final result = const Recurrence(RecurrenceType.weekly, interval: 2)
          .occurrencesBetween(
            anchor: d(2026, 1, 5),
            from: d(2026, 1, 1),
            to: d(2026, 2, 10),
          );
      expect(result, equals([d(2026, 1, 5), d(2026, 1, 19), d(2026, 2, 2)]));
    });
  });

  // ---------------------------------------------------------------------
  // Monthly — where the real difficulty lives
  // ---------------------------------------------------------------------
  group('monthly', () {
    test('same day each month', () {
      final result = const Recurrence(RecurrenceType.monthly)
          .occurrencesBetween(
            anchor: d(2026, 1, 15),
            from: d(2026, 1, 1),
            to: d(2026, 4, 30),
          );
      expect(
        result,
        equals([
          d(2026, 1, 15),
          d(2026, 2, 15),
          d(2026, 3, 15),
          d(2026, 4, 15),
        ]),
      );
    });

    test('day 31 clamps to the last day of a short month', () {
      final result = const Recurrence(RecurrenceType.monthly)
          .occurrencesBetween(
            anchor: d(2026, 1, 31),
            from: d(2026, 1, 1),
            to: d(2026, 4, 30),
          );
      expect(
        result,
        equals([
          d(2026, 1, 31),
          d(2026, 2, 28), // 2026 is not a leap year
          d(2026, 3, 31), // back to 31 — must NOT stay at 28
          d(2026, 4, 30),
        ]),
      );
    });

    test('clamping never drifts: the anchor day is always restored', () {
      final result = const Recurrence(RecurrenceType.monthly)
          .occurrencesBetween(
            anchor: d(2026, 1, 31),
            from: d(2026, 1, 1),
            to: d(2026, 12, 31),
          );
      // Every month that has 31 days must land on the 31st.
      expect(result[0].day, equals(31)); // Jan
      expect(result[4].day, equals(31)); // May
      expect(result[6].day, equals(31)); // Jul
      expect(result[11].day, equals(31)); // Dec
    });

    test('day 29 in a leap year', () {
      final result = const Recurrence(RecurrenceType.monthly)
          .occurrencesBetween(
            anchor: d(2024, 1, 29),
            from: d(2024, 1, 1),
            to: d(2024, 3, 31),
          );
      expect(result, equals([d(2024, 1, 29), d(2024, 2, 29), d(2024, 3, 29)]));
    });

    test('day 30 clamps in February of a leap year', () {
      final result = const Recurrence(RecurrenceType.monthly)
          .occurrencesBetween(
            anchor: d(2024, 1, 30),
            from: d(2024, 2, 1),
            to: d(2024, 2, 29),
          );
      expect(result, equals([d(2024, 2, 29)]));
    });

    test('crosses a year boundary', () {
      final result = const Recurrence(RecurrenceType.monthly)
          .occurrencesBetween(
            anchor: d(2026, 11, 10),
            from: d(2026, 11, 1),
            to: d(2027, 2, 28),
          );
      expect(
        result,
        equals([
          d(2026, 11, 10),
          d(2026, 12, 10),
          d(2027, 1, 10),
          d(2027, 2, 10),
        ]),
      );
    });

    test('every two months', () {
      final result = const Recurrence(RecurrenceType.monthly, interval: 2)
          .occurrencesBetween(
            anchor: d(2026, 1, 10),
            from: d(2026, 1, 1),
            to: d(2026, 6, 30),
          );
      expect(result, equals([d(2026, 1, 10), d(2026, 3, 10), d(2026, 5, 10)]));
    });
  });

  // ---------------------------------------------------------------------
  // Range behaviour
  // ---------------------------------------------------------------------
  group('range', () {
    test('skips occurrences before the range starts', () {
      final result = const Recurrence(RecurrenceType.monthly)
          .occurrencesBetween(
            anchor: d(2026, 1, 15),
            from: d(2026, 3, 1),
            to: d(2026, 4, 30),
          );
      expect(result, equals([d(2026, 3, 15), d(2026, 4, 15)]));
    });

    test('returns empty when the anchor is after the range', () {
      final result = const Recurrence(RecurrenceType.monthly)
          .occurrencesBetween(
            anchor: d(2026, 6, 1),
            from: d(2026, 1, 1),
            to: d(2026, 3, 1),
          );
      expect(result, isEmpty);
    });

    test('a single-day range containing an occurrence returns it', () {
      final result = const Recurrence(RecurrenceType.daily).occurrencesBetween(
        anchor: d(2026, 1, 1),
        from: d(2026, 1, 5),
        to: d(2026, 1, 5),
      );
      expect(result, equals([d(2026, 1, 5)]));
    });

    test('results are sorted ascending', () {
      final result = const Recurrence(RecurrenceType.monthly)
          .occurrencesBetween(
            anchor: d(2026, 1, 31),
            from: d(2026, 1, 1),
            to: d(2026, 12, 31),
          );
      for (var i = 1; i < result.length; i++) {
        expect(result[i].isAfter(result[i - 1]), isTrue);
      }
    });
  });

  // ---------------------------------------------------------------------
  // Normalisation — a due date is a date, never a moment.
  // ---------------------------------------------------------------------
  group('normalisation', () {
    test('strips the time component from the anchor', () {
      final result = const Recurrence(RecurrenceType.daily).occurrencesBetween(
        anchor: DateTime(2026, 1, 1, 14, 37, 22),
        from: d(2026, 1, 1),
        to: d(2026, 1, 2),
      );
      expect(result, equals([d(2026, 1, 1), d(2026, 1, 2)]));
    });

    test('a range end late in the day still includes that day', () {
      final result = const Recurrence(RecurrenceType.daily).occurrencesBetween(
        anchor: d(2026, 1, 1),
        from: d(2026, 1, 1),
        to: DateTime(2026, 1, 3, 23, 59),
      );
      expect(result, hasLength(3));
    });
  });

  // ---------------------------------------------------------------------
  // Value semantics
  // ---------------------------------------------------------------------
  group('equality', () {
    test('same type and interval are equal', () {
      expect(
        const Recurrence(RecurrenceType.monthly, interval: 2),
        equals(const Recurrence(RecurrenceType.monthly, interval: 2)),
      );
    });

    test('different intervals are not equal', () {
      expect(
        const Recurrence(RecurrenceType.monthly),
        isNot(equals(const Recurrence(RecurrenceType.monthly, interval: 2))),
      );
    });

    test('equal instances share a hashCode', () {
      expect(
        const Recurrence(RecurrenceType.weekly).hashCode,
        equals(const Recurrence(RecurrenceType.weekly).hashCode),
      );
    });
  });
}
