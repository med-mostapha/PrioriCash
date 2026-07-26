import 'package:meta/meta.dart';

/// How often an obligation repeats.
///
/// `yearly` and `custom` are deliberately absent: they are deferred to
/// Sprint 2 per the risk register in BACKLOG.md. Adding them here without
/// tests would be the exact scope creep AGENTS.md §3.2 forbids.
enum RecurrenceType { daily, weekly, monthly }

/// A repetition rule. Pure value object: no clock, no I/O, no storage.
///
/// All dates are date-only. A due date is a day, not a moment, so the time
/// component of every input is stripped and every output is midnight local.
@immutable
class Recurrence {
  const Recurrence(this.type, {this.interval = 1});

  /// Safety valve. A 30-day horizon can never legitimately produce this
  /// many occurrences; hitting it means the interval arithmetic is wrong.
  static const int _maxOccurrences = 10000;

  final RecurrenceType type;

  /// Repeat every [interval] periods. 2 + weekly = every two weeks.
  final int interval;

  /// Every occurrence falling within `[from, to]`, both ends inclusive.
  ///
  /// [anchor] is the obligation's start date and defines the day-of-month
  /// or day-of-week that the series keeps.
  ///
  /// Occurrences before [from] are skipped, not returned: an obligation
  /// that started a year ago still has its next due date computed correctly.
  List<DateTime> occurrencesBetween({
    required DateTime anchor,
    required DateTime from,
    required DateTime to,
  }) {
    if (interval < 1) {
      throw ArgumentError.value(interval, 'interval', 'must be at least 1');
    }

    final start = _dateOnly(from);
    final end = _dateOnly(to);
    if (start.isAfter(end)) {
      throw ArgumentError('Range runs backwards: $from is after $to');
    }

    final base = _dateOnly(anchor);
    final result = <DateTime>[];

    for (var step = 0; step < _maxOccurrences; step++) {
      final occurrence = _occurrenceAt(base, step);

      if (occurrence.isAfter(end)) {
        return result;
      }
      if (!occurrence.isBefore(start)) {
        result.add(occurrence);
      }
    }

    throw StateError(
      'Occurrence limit reached: check interval and range bounds',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Recurrence && other.type == type && other.interval == interval;

  @override
  int get hashCode => Object.hash(type, interval);

  @override
  String toString() => 'every $interval ${type.name}';

  /// The [step]-th occurrence counted from [base].
  ///
  /// Always computed from [base], never from the previous occurrence. This
  /// is what stops a day-31 obligation from drifting: February clamps to
  /// the 28th, and March returns to the 31st rather than staying at 28.
  DateTime _occurrenceAt(DateTime base, int step) {
    final offset = step * interval;
    switch (type) {
      case RecurrenceType.daily:
        return DateTime(base.year, base.month, base.day + offset);
      case RecurrenceType.weekly:
        return DateTime(base.year, base.month, base.day + offset * 7);
      case RecurrenceType.monthly:
        return _addMonths(base, offset);
    }
  }

  /// Adds whole months, clamping the day to the last valid day of the
  /// target month.
  ///
  /// Plain `DateTime(2026, 2, 31)` silently rolls forward to 3 March, which
  /// would move a rent payment into the wrong month. Clamping keeps it on
  /// 28 February, which is what the bank does.
  static DateTime _addMonths(DateTime base, int months) {
    final zeroBased = base.month - 1 + months;
    final year = base.year + zeroBased ~/ 12;
    final month = zeroBased % 12 + 1;

    // Day 0 of the following month is the last day of this one.
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final day = base.day <= lastDayOfMonth ? base.day : lastDayOfMonth;

    return DateTime(year, month, day);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
