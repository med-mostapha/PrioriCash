import 'package:meta/meta.dart';

/// A currency the person can choose in Settings — SW-20.
///
/// Deliberately closed to three members, all with the same minor-unit
/// exponent (2 decimal places) as MRU, so Money.minorUnitsPerMajor (a
/// fixed 100) stays valid for all of them without restructuring Money
/// itself. A currency with a different exponent (e.g. JPY has none, KWD
/// has three) is out of scope — see the SW-20 planning discussion.
///
/// [code] is the persisted wire value (settings.currency column), chosen
/// to match the pre-existing default `'MRU'` already in tables.dart from
/// Sprint 1, rather than the enum member's own name.
enum CurrencyId {
  mru('MRU'),
  usd('USD'),
  eur('EUR');

  const CurrencyId(this.code);

  final String code;

  static CurrencyId fromCode(String code) => CurrencyId.values.firstWhere(
    (c) => c.code == code,
    orElse: () =>
        throw ArgumentError.value(code, 'code', 'unknown currency code'),
  );
}

/// App-wide preferences — SW-20 (R18).
///
/// [horizonDays] is fully wired: HomeScreen, AddIncomeScreen, and every
/// other horizon consumer read this instead of a hardcoded constant.
///
/// [currency] is stored and shown, but **not yet applied** to new Money
/// values anywhere — Money.zero and several domain entities (e.g.
/// ObligationInstance.fundedAmount's default) are hardcoded to MRU deep
/// enough that wiring currency through them is its own follow-up item,
/// not part of SW-20 — see DOCS.md's SW-20 discussion for why.
@immutable
class Settings {
  Settings({required this.horizonDays, required this.currency}) {
    if (horizonDays <= 0) {
      throw ArgumentError.value(
        horizonDays,
        'horizonDays',
        'must be positive',
      );
    }
  }

  final int horizonDays;
  final CurrencyId currency;

  Settings copyWith({int? horizonDays, CurrencyId? currency}) {
    return Settings(
      horizonDays: horizonDays ?? this.horizonDays,
      currency: currency ?? this.currency,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Settings &&
      other.horizonDays == horizonDays &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(horizonDays, currency);

  @override
  String toString() =>
      'Settings(horizonDays: $horizonDays, currency: $currency)';
}