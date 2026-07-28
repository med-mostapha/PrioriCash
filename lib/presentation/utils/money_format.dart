import 'package:prioricash/domain/value_objects/money.dart';

abstract final class MoneyFormat {
  /// "8000.00" -> "8,000.00", "-300000" minor -> "-3,000.00".
  static String display(Money amount) {
    final absolute = amount.minorUnits.abs();
    final major = absolute ~/ Money.minorUnitsPerMajor;
    final fraction = absolute % Money.minorUnitsPerMajor;
    final sign = amount.isNegative ? '-' : '';
    return '$sign${_thousands(major)}.${fraction.toString().padLeft(2, '0')}';
  }

  /// The integer part only, with thousands separators and sign — used by
  /// HeroBalanceText, which renders the fraction separately in a smaller,
  /// muted style.
  static String integerPart(Money amount) {
    final major = amount.minorUnits.abs() ~/ Money.minorUnitsPerMajor;
    return '${amount.isNegative ? '-' : ''}${_thousands(major)}';
  }

  /// The fractional part only, e.g. ".00" or ".50" — no sign.
  static String fractionPart(Money amount) {
    final fraction = amount.minorUnits.abs() % Money.minorUnitsPerMajor;
    return '.${fraction.toString().padLeft(2, '0')}';
  }

  static String _thousands(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
