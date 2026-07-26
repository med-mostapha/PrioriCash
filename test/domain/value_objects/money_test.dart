import 'package:flutter_test/flutter_test.dart';
import 'package:prioricash/domain/value_objects/money.dart';

/// SW-2 — Money value object.
///
/// These tests are written BEFORE money.dart exists. They define the API.
/// Every test here must fail to compile right now — that is the point.
///
/// Traces: R11 (money is an integer in minor units, never floating point).
void main() {
  // ---------------------------------------------------------------------
  // Construction
  //
  // MRU is formally non-decimal (1 ouguiya = 5 khoums), but khoums are no
  // longer in circulation. We follow ISO 4217 exponent 2 so that intl's
  // NumberFormat.currency works without custom handling.
  // ---------------------------------------------------------------------
  group('construction', () {
    test('minorUnitsPerMajor is 100 (ISO 4217 exponent 2)', () {
      expect(Money.minorUnitsPerMajor, equals(100));
    });

    test('fromMinor stores the exact integer given', () {
      final m = Money.fromMinor(1350);
      expect(m.minorUnits, equals(1350));
    });

    test('fromMajor multiplies by 100', () {
      final m = Money.fromMajor(1350);
      expect(m.minorUnits, equals(135000));
    });

    test('defaults to MRU', () {
      expect(Money.fromMinor(1).currency, equals('MRU'));
    });

    test('accepts an explicit currency', () {
      expect(Money.fromMinor(1, currency: 'EUR').currency, equals('EUR'));
    });

    test('rejects an empty currency code', () {
      expect(() => Money.fromMinor(1, currency: ''), throwsArgumentError);
    });
  });

  // ---------------------------------------------------------------------
  // Zero — the identity element. Used as the seed of every fold in the
  // balance calculator, so it has to behave exactly.
  // ---------------------------------------------------------------------
  group('zero', () {
    test('has no minor units', () {
      expect(Money.zero.minorUnits, equals(0));
    });

    test('isZero is true only for zero', () {
      expect(Money.zero.isZero, isTrue);
      expect(Money.fromMinor(1).isZero, isFalse);
      expect(Money.fromMinor(-1).isZero, isFalse);
    });

    test('adding zero changes nothing', () {
      final m = Money.fromMinor(500);
      expect(m.add(Money.zero), equals(m));
    });
  });

  // ---------------------------------------------------------------------
  // Equality — Money is compared throughout the allocation engine and is
  // put into sets and map keys. A missing hashCode fails silently.
  // ---------------------------------------------------------------------
  group('equality', () {
    test('same amount and currency are equal', () {
      expect(Money.fromMinor(500), equals(Money.fromMinor(500)));
    });

    test('different amounts are not equal', () {
      expect(Money.fromMinor(500), isNot(equals(Money.fromMinor(501))));
    });

    test('same amount in different currencies is not equal', () {
      expect(
        Money.fromMinor(500, currency: 'MRU'),
        isNot(equals(Money.fromMinor(500, currency: 'EUR'))),
      );
    });

    test('equal instances share a hashCode', () {
      expect(
        Money.fromMinor(500).hashCode,
        equals(Money.fromMinor(500).hashCode),
      );
    });

    test('behaves correctly inside a Set', () {
      final set = {Money.fromMinor(500), Money.fromMinor(500)};
      expect(set, hasLength(1));
    });
  });

  // ---------------------------------------------------------------------
  // Arithmetic
  // ---------------------------------------------------------------------
  group('add and subtract', () {
    test('adds', () {
      expect(
        Money.fromMinor(300).add(Money.fromMinor(200)),
        equals(Money.fromMinor(500)),
      );
    });

    test('subtracts', () {
      expect(
        Money.fromMinor(500).subtract(Money.fromMinor(200)),
        equals(Money.fromMinor(300)),
      );
    });

    test('subtraction may go negative — R5 forbids clamping', () {
      final result = Money.fromMinor(100).subtract(Money.fromMinor(400));
      expect(result.minorUnits, equals(-300));
      expect(result.isNegative, isTrue);
    });

    test('does not mutate its operands', () {
      final a = Money.fromMinor(300);
      final b = Money.fromMinor(200);
      a.add(b);
      expect(a.minorUnits, equals(300));
      expect(b.minorUnits, equals(200));
    });
  });

  // ---------------------------------------------------------------------
  // Currency mismatch — must be loud. Silently adding MRU to EUR would
  // corrupt every balance downstream.
  // ---------------------------------------------------------------------
  group('currency mismatch', () {
    final mru = Money.fromMinor(100);
    final eur = Money.fromMinor(100, currency: 'EUR');

    test('add throws', () {
      expect(() => mru.add(eur), throwsArgumentError);
    });

    test('subtract throws', () {
      expect(() => mru.subtract(eur), throwsArgumentError);
    });

    test('min throws', () {
      expect(() => mru.min(eur), throwsArgumentError);
    });

    test('compareTo throws', () {
      expect(() => mru.compareTo(eur), throwsArgumentError);
    });
  });

  // ---------------------------------------------------------------------
  // Overflow — Dart's int is 64-bit and wraps around silently on native.
  // A wrapped balance is a wrong number displayed confidently.
  // ---------------------------------------------------------------------
  group('overflow', () {
    test('addition overflow throws instead of wrapping', () {
      final huge = Money.fromMinor(9223372036854775807);
      expect(() => huge.add(Money.fromMinor(1)), throwsA(isA<StateError>()));
    });

    test('subtraction underflow throws instead of wrapping', () {
      final tiny = Money.fromMinor(-9223372036854775808);
      expect(
        () => tiny.subtract(Money.fromMinor(1)),
        throwsA(isA<StateError>()),
      );
    });

    test('fromMajor overflow throws', () {
      expect(
        () => Money.fromMajor(9223372036854775807),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ---------------------------------------------------------------------
  // Comparison — the allocation engine takes min(remaining, shortfall) on
  // every step.
  // ---------------------------------------------------------------------
  group('comparison', () {
    test('min returns the smaller', () {
      expect(
        Money.fromMinor(500).min(Money.fromMinor(200)),
        equals(Money.fromMinor(200)),
      );
    });

    test('min handles negatives', () {
      expect(
        Money.fromMinor(-500).min(Money.fromMinor(200)),
        equals(Money.fromMinor(-500)),
      );
    });

    test('isNegative is false for zero', () {
      expect(Money.zero.isNegative, isFalse);
    });

    test('compareTo orders correctly', () {
      expect(Money.fromMinor(100).compareTo(Money.fromMinor(200)), lessThan(0));
      expect(
        Money.fromMinor(200).compareTo(Money.fromMinor(100)),
        greaterThan(0),
      );
      expect(Money.fromMinor(100).compareTo(Money.fromMinor(100)), equals(0));
    });

    test('sorts a list', () {
      final list = [
        Money.fromMinor(300),
        Money.fromMinor(100),
        Money.fromMinor(200),
      ]..sort();
      expect(list.map((m) => m.minorUnits), equals([100, 200, 300]));
    });
  });

  // ---------------------------------------------------------------------
  // Parsing user input.
  //
  // NEVER use NumberFormat.parse here: it returns num, which is a direct
  // Tier 1 violation. Parsing stays integer-only.
  // ---------------------------------------------------------------------
  group('parse', () {
    test('parses a whole number as major units', () {
      expect(Money.parse('1350'), equals(Money.fromMinor(135000)));
    });

    test('parses two decimal places', () {
      expect(Money.parse('13.50'), equals(Money.fromMinor(1350)));
    });

    test('parses one decimal place', () {
      expect(Money.parse('13.5'), equals(Money.fromMinor(1350)));
    });

    test('trims surrounding whitespace', () {
      expect(Money.parse('  42  '), equals(Money.fromMinor(4200)));
    });

    test('parses zero', () {
      expect(Money.parse('0'), equals(Money.zero));
    });

    test('rejects more than two decimal places', () {
      expect(() => Money.parse('13.505'), throwsFormatException);
    });

    test('rejects non-numeric input', () {
      expect(() => Money.parse('abc'), throwsFormatException);
      expect(() => Money.parse(''), throwsFormatException);
      expect(() => Money.parse('1.2.3'), throwsFormatException);
    });

    test('rejects a negative literal — use subtract instead', () {
      expect(() => Money.parse('-5'), throwsFormatException);
    });
  });

  // ---------------------------------------------------------------------
  // toString is for debugging and test output only. User-facing formatting
  // belongs in the presentation layer with intl.
  // ---------------------------------------------------------------------
  group('toString', () {
    test('shows amount and currency', () {
      expect(Money.fromMinor(135000).toString(), equals('1350.00 MRU'));
    });

    test('pads the minor part', () {
      expect(Money.fromMinor(1305).toString(), equals('13.05 MRU'));
    });

    test('shows the sign for negatives', () {
      expect(Money.fromMinor(-1350).toString(), equals('-13.50 MRU'));
    });
  });
}
