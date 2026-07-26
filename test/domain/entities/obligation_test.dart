import 'package:flutter_test/flutter_test.dart';
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/domain/value_objects/recurrence.dart';

/// SW-4 — Obligation (the recurring template).
void main() {
  DateTime d(int year, int month, int day) => DateTime(year, month, day);

  Obligation build({
    String id = 'ob-1',
    String name = 'Wi-Fi',
    int amountMinor = 50000,
    Recurrence recurrence = const Recurrence(RecurrenceType.monthly),
    Priority priority = Priority.high,
    DateTime? startDate,
    bool isEssential = true,
    bool isActive = true,
  }) {
    return Obligation(
      id: id,
      name: name,
      amount: Money.fromMinor(amountMinor),
      recurrence: recurrence,
      priority: priority,
      startDate: startDate ?? d(2026, 1, 5),
      isEssential: isEssential,
      isActive: isActive,
    );
  }

  group('construction', () {
    test('keeps the values given', () {
      final ob = build();
      expect(ob.id, equals('ob-1'));
      expect(ob.name, equals('Wi-Fi'));
      expect(ob.amount, equals(Money.fromMinor(50000)));
      expect(ob.priority, equals(Priority.high));
      expect(ob.isEssential, isTrue);
      expect(ob.isActive, isTrue);
    });

    test('defaults to essential and active', () {
      final ob = Obligation(
        id: 'ob-2',
        name: 'Rent',
        amount: Money.fromMinor(300000),
        recurrence: const Recurrence(RecurrenceType.monthly),
        priority: Priority.high,
        startDate: d(2026, 1, 1),
      );
      expect(ob.isEssential, isTrue);
      expect(ob.isActive, isTrue);
    });

    test('rejects an empty id', () {
      expect(() => build(id: ''), throwsArgumentError);
    });

    test('rejects a blank name', () {
      expect(() => build(name: ''), throwsArgumentError);
      expect(() => build(name: '   '), throwsArgumentError);
    });

    test('rejects a zero or negative amount', () {
      expect(() => build(amountMinor: 0), throwsArgumentError);
      expect(() => build(amountMinor: -100), throwsArgumentError);
    });
  });

  // -----------------------------------------------------------------------
  // Priority is a tie-breaker only. Its declaration order IS the sort order,
  // so this test guards against someone reordering the enum. See SRS R6.
  // -----------------------------------------------------------------------
  group('priority ordering', () {
    test('high sorts before medium before low', () {
      expect(Priority.high.index, lessThan(Priority.medium.index));
      expect(Priority.medium.index, lessThan(Priority.low.index));
    });

    test('sorting by index puts high first', () {
      final list = [Priority.low, Priority.high, Priority.medium]
        ..sort((a, b) => a.index.compareTo(b.index));
      expect(list, equals([Priority.high, Priority.medium, Priority.low]));
    });
  });

  group('dueDatesBetween', () {
    test('delegates to the recurrence, anchored on startDate', () {
      final ob = build(startDate: d(2026, 1, 15));
      final dates = ob.dueDatesBetween(from: d(2026, 1, 1), to: d(2026, 3, 31));
      expect(dates, equals([d(2026, 1, 15), d(2026, 2, 15), d(2026, 3, 15)]));
    });

    test('handles a day-31 anchor without drifting', () {
      final ob = build(startDate: d(2026, 1, 31));
      final dates = ob.dueDatesBetween(from: d(2026, 1, 1), to: d(2026, 3, 31));
      expect(dates, equals([d(2026, 1, 31), d(2026, 2, 28), d(2026, 3, 31)]));
    });

    test('weekly obligations work too', () {
      final ob = build(
        recurrence: const Recurrence(RecurrenceType.weekly),
        startDate: d(2026, 1, 5),
      );
      final dates = ob.dueDatesBetween(from: d(2026, 1, 1), to: d(2026, 1, 26));
      expect(dates, hasLength(4));
    });

    test('an inactive obligation generates nothing', () {
      final ob = build(isActive: false);
      final dates = ob.dueDatesBetween(
        from: d(2026, 1, 1),
        to: d(2026, 12, 31),
      );
      expect(dates, isEmpty);
    });

    test('nothing before the start date', () {
      final ob = build(startDate: d(2026, 6, 10));
      final dates = ob.dueDatesBetween(from: d(2026, 1, 1), to: d(2026, 5, 31));
      expect(dates, isEmpty);
    });
  });

  group('deactivate and copyWith', () {
    test('deactivate clears isActive without touching anything else', () {
      final ob = build();
      final off = ob.deactivate();
      expect(off.isActive, isFalse);
      expect(off.id, equals(ob.id));
      expect(off.name, equals(ob.name));
      expect(off.amount, equals(ob.amount));
    });

    test('deactivate does not mutate the original', () {
      final ob = build();
      ob.deactivate();
      expect(ob.isActive, isTrue);
    });

    test('copyWith replaces only the named fields', () {
      final ob = build();
      final renamed = ob.copyWith(name: 'Internet', priority: Priority.low);
      expect(renamed.name, equals('Internet'));
      expect(renamed.priority, equals(Priority.low));
      expect(renamed.amount, equals(ob.amount));
      expect(renamed.isEssential, equals(ob.isEssential));
    });

    test('copyWith keeps the id — it is the identity', () {
      expect(build().copyWith(name: 'Other').id, equals('ob-1'));
    });

    test('copyWith still validates', () {
      expect(() => build().copyWith(name: ''), throwsArgumentError);
    });
  });

  // -----------------------------------------------------------------------
  // Entity equality: identity is the id. Renaming an obligation does not
  // make it a different obligation. Contrast with Money, a value object,
  // where the amount IS the identity.
  // -----------------------------------------------------------------------
  group('entity equality', () {
    test('same id means equal even with different contents', () {
      expect(build(name: 'Wi-Fi'), equals(build(name: 'Internet')));
    });

    test('different ids are not equal', () {
      expect(build(id: 'ob-1'), isNot(equals(build(id: 'ob-2'))));
    });

    test('equal instances share a hashCode', () {
      expect(build().hashCode, equals(build(name: 'Other').hashCode));
    });

    test('deduplicates by id inside a Set', () {
      final set = {build(name: 'A'), build(name: 'B')};
      expect(set, hasLength(1));
    });
  });
}
