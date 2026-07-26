import 'package:meta/meta.dart';

/// An amount of money held as an integer number of minor units.
///
/// Never use `double` for money: binary floating point cannot represent
/// values like 0.10 exactly, and the error compounds across a ledger.
/// See AGENTS.md §1.1 and SRS R11.
///
/// MRU is formally non-decimal (1 ouguiya = 5 khoums), but khoums are no
/// longer in circulation. We follow ISO 4217 exponent 2 so that intl's
/// NumberFormat.currency works without custom handling.
@immutable
class Money implements Comparable<Money> {
  const Money._(this.minorUnits, this.currency);

  /// Builds from a raw minor-unit count. 1350 -> 13.50 MRU.
  factory Money.fromMinor(int minorUnits, {String currency = defaultCurrency}) {
    _requireCurrency(currency);
    return Money._(minorUnits, currency);
  }

  /// Builds from whole major units. 1350 -> 1350.00 MRU.
  factory Money.fromMajor(int major, {String currency = defaultCurrency}) {
    _requireCurrency(currency);
    return Money._(_checkedMultiply(major, minorUnitsPerMajor), currency);
  }

  /// Parses user input such as `"1350"`, `"13.50"` or `"13.5"`.
  ///
  /// Deliberately hand-written: `NumberFormat.parse` returns `num`, which
  /// would put a floating-point value on a money path.
  factory Money.parse(String input, {String currency = defaultCurrency}) {
    _requireCurrency(currency);
    final trimmed = input.trim();

    final match = _inputPattern.firstMatch(trimmed);
    if (match == null) {
      throw FormatException('Not a valid amount', input);
    }

    final major = int.parse(match.group(1)!);
    // '5' -> 50 khoums-equivalent, '50' -> 50, absent -> 0.
    final fraction = int.parse((match.group(2) ?? '').padRight(2, '0'));

    return Money._(
      _checkedAdd(_checkedMultiply(major, minorUnitsPerMajor), fraction),
      currency,
    );
  }

  /// Number of minor units in one major unit (ISO 4217 exponent 2).
  static const int minorUnitsPerMajor = 100;

  /// Currency used when none is given. Single-currency in v1.
  static const String defaultCurrency = 'MRU';

  /// The additive identity. Seed value for every fold in BalanceCalculator.
  static const Money zero = Money._(0, defaultCurrency);

  /// Digits, optionally followed by one or two decimal places. No sign:
  /// negatives are produced by [subtract], never typed by a user.
  static final RegExp _inputPattern = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$');

  /// The amount, in minor units. Always exact.
  final int minorUnits;

  /// ISO 4217 code, e.g. `MRU`.
  final String currency;

  bool get isZero => minorUnits == 0;

  /// True only below zero. Zero itself is not negative.
  ///
  /// A negative balance is a real, displayable state — see R5. Nothing in
  /// this class may clamp it away.
  bool get isNegative => minorUnits < 0;

  Money add(Money other) {
    _requireSameCurrency(other);
    return Money._(_checkedAdd(minorUnits, other.minorUnits), currency);
  }

  /// May return a negative result. That is intended: it is how the app
  /// reports that commitments exceed holdings.
  Money subtract(Money other) {
    _requireSameCurrency(other);
    return Money._(_checkedSubtract(minorUnits, other.minorUnits), currency);
  }

  /// The smaller of the two. Used on every allocation step:
  /// `min(remaining, shortfall)`.
  Money min(Money other) {
    _requireSameCurrency(other);
    return minorUnits <= other.minorUnits ? this : other;
  }

  @override
  int compareTo(Money other) {
    _requireSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  /// Debugging and test output only. User-facing formatting belongs in the
  /// presentation layer, where intl and the active locale are available.
  @override
  String toString() {
    final sign = minorUnits < 0 ? '-' : '';
    final absolute = minorUnits.abs();
    final major = absolute ~/ minorUnitsPerMajor;
    final fraction = absolute % minorUnitsPerMajor;
    return '$sign$major.${fraction.toString().padLeft(2, '0')} $currency';
  }

  static void _requireCurrency(String currency) {
    if (currency.isEmpty) {
      throw ArgumentError.value(currency, 'currency', 'must not be empty');
    }
  }

  void _requireSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('Currency mismatch: $currency and ${other.currency}');
    }
  }

  // -------------------------------------------------------------------------
  // Overflow guards.
  //
  // Dart's int is 64-bit and wraps around silently on native platforms. A
  // wrapped total is a wrong number displayed with full confidence, which is
  // the one outcome this project treats as unacceptable.
  // -------------------------------------------------------------------------

  static int _checkedAdd(int a, int b) {
    final sum = a + b;
    if ((b > 0 && sum < a) || (b < 0 && sum > a)) {
      throw StateError('Money overflow: $a + $b');
    }
    return sum;
  }

  static int _checkedSubtract(int a, int b) {
    final difference = a - b;
    if ((b > 0 && difference > a) || (b < 0 && difference < a)) {
      throw StateError('Money overflow: $a - $b');
    }
    return difference;
  }

  static int _checkedMultiply(int a, int b) {
    if (a == 0 || b == 0) {
      return 0;
    }
    final product = a * b;
    if (product ~/ b != a) {
      throw StateError('Money overflow: $a * $b');
    }
    return product;
  }
}
