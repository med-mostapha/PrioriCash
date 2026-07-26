import 'package:meta/meta.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/domain/value_objects/recurrence.dart';

/// How important an obligation is, used only as a tie-breaker.
enum Priority { high, medium, low }

/// A recurring commitment: the template, not a dated occurrence of it.
@immutable
class Obligation {
  Obligation({
    required this.id,
    required this.name,
    required this.amount,
    required this.recurrence,
    required this.priority,
    required this.startDate,
    this.isEssential = true,
    this.isActive = true,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    if (amount.isZero || amount.isNegative) {
      throw ArgumentError.value(amount, 'amount', 'must be positive');
    }
  }

  final String id;
  final String name;

  /// Amount due on each occurrence.
  final Money amount;

  final Recurrence recurrence;
  final Priority priority;

  /// First occurrence. Also the anchor that fixes the day-of-month or
  final DateTime startDate;

  /// Only essential obligations are funded automatically. Discretionary ones
  final bool isEssential;

  /// Deactivated obligations stop generating occurrences but keep their
  final bool isActive;

  /// Every due date in `[from, to]`, both ends inclusive.
  List<DateTime> dueDatesBetween({
    required DateTime from,
    required DateTime to,
  }) {
    if (!isActive) {
      return const [];
    }
    return recurrence.occurrencesBetween(anchor: startDate, from: from, to: to);
  }

  Obligation deactivate() => copyWith(isActive: false);

  Obligation copyWith({
    String? name,
    Money? amount,
    Recurrence? recurrence,
    Priority? priority,
    DateTime? startDate,
    bool? isEssential,
    bool? isActive,
  }) {
    return Obligation(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      recurrence: recurrence ?? this.recurrence,
      priority: priority ?? this.priority,
      startDate: startDate ?? this.startDate,
      isEssential: isEssential ?? this.isEssential,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Entity equality: identity is the id, not the contents. Renaming an
  /// obligation does not make it a different obligation.
  @override
  bool operator ==(Object other) => other is Obligation && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Obligation($id, $name, $amount, ${priority.name})';
}
