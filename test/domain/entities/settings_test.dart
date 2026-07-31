import 'package:flutter_test/flutter_test.dart';
import 'package:prioricash/domain/entities/settings.dart';

/// SW-20 — Settings entity and CurrencyId.
void main() {
  group('CurrencyId', () {
    test('codes match the pre-existing tables.dart default (MRU)', () {
      expect(CurrencyId.mru.code, 'MRU');
      expect(CurrencyId.usd.code, 'USD');
      expect(CurrencyId.eur.code, 'EUR');
    });

    test('fromCode resolves a known code', () {
      expect(CurrencyId.fromCode('USD'), CurrencyId.usd);
    });

    test('fromCode rejects an unknown code', () {
      expect(() => CurrencyId.fromCode('JPY'), throwsArgumentError);
    });
  });

  group('Settings', () {
    test('holds the values it was given', () {
      final settings = Settings(horizonDays: 45, currency: CurrencyId.usd);
      expect(settings.horizonDays, 45);
      expect(settings.currency, CurrencyId.usd);
    });

    test('rejects a zero horizon', () {
      expect(
        () => Settings(horizonDays: 0, currency: CurrencyId.mru),
        throwsArgumentError,
      );
    });

    test('rejects a negative horizon', () {
      expect(
        () => Settings(horizonDays: -1, currency: CurrencyId.mru),
        throwsArgumentError,
      );
    });

    test('copyWith changes only the given field', () {
      final settings = Settings(horizonDays: 30, currency: CurrencyId.mru);
      final updated = settings.copyWith(currency: CurrencyId.eur);

      expect(updated.currency, CurrencyId.eur);
      expect(updated.horizonDays, 30);
    });

    test('equality is by value, not identity', () {
      final a = Settings(horizonDays: 30, currency: CurrencyId.mru);
      final b = Settings(horizonDays: 30, currency: CurrencyId.mru);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}