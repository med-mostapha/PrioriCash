import 'package:drift/drift.dart';

class IncomeSources extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A single received amount. Never assumed to arrive on a fixed schedule —
/// see SRS R1.
class Incomes extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId =>
      text().references(IncomeSources, #id, onDelete: KeyAction.restrict)();
  IntColumn get amountMinor => integer()();
  DateTimeColumn get receivedAt => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

/// The recurring template — SRS §6.1. Not a dated occurrence; see
/// [ObligationInstances] for that.
class Obligations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get amountMinor => integer()();

  /// 'weekly' or 'monthly' in v1 — see BACKLOG.md risk table. 'yearly' and
  /// 'custom' are Sprint 2.
  TextColumn get recurrenceType => text()();
  IntColumn get recurrenceInterval =>
      integer().withDefault(const Constant(1))();

  /// Stores Priority.index (0 = high, 1 = medium, 2 = low). A tie-breaker
  /// only — see R6.
  IntColumn get priority => integer()();

  /// Gates automatic funding — see R7. Only essential obligations are
  /// funded before discretionary spending or savings goals.
  BoolColumn get isEssential => boolean().withDefault(const Constant(true))();
  DateTimeColumn get startDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One dated occurrence of an [Obligations] template, with its own funding
/// progress. See SRS §6.1 and §6.2.
///
/// No `status` column — see the file-level note above.
class ObligationInstances extends Table {
  TextColumn get id => text()();
  TextColumn get obligationId =>
      text().references(Obligations, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get amountMinor => integer()();
  IntColumn get fundedMinor => integer().withDefault(const Constant(0))();
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Minimal savings-goal shape, matching the domain entity built for SW-6.
/// The full entity (name, isActive, CRUD) lands in SW-19.
class SavingsGoals extends Table {
  TextColumn get id => text()();
  IntColumn get targetMinor => integer()();
  IntColumn get currentMinor => integer().withDefault(const Constant(0))();

  /// Priority.index — same tie-breaker semantics as Obligations.priority.
  IntColumn get priority => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A category for expenses, e.g. "food", "transport". Free text, not an
/// enum, for the same reason as IncomeSources.type.
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_allocations_income', columns: {#incomeId, #isReversed})
class Allocations extends Table {
  TextColumn get id => text()();
  TextColumn get incomeId =>
      text().references(Incomes, #id, onDelete: KeyAction.cascade)();
  TextColumn get instanceId => text().nullable().references(
    ObligationInstances,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get goalId => text().nullable().references(
    SavingsGoals,
    #id,
    onDelete: KeyAction.restrict,
  )();
  IntColumn get amountMinor => integer()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isReversed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    // At most one target: an instance, a goal, or neither (free
    // balance). Never both. See SRS R9.
    'CHECK ((instance_id IS NOT NULL) + (goal_id IS NOT NULL) <= 1)',
    'CHECK (amount_minor > 0)',
  ];
}

/// One recorded expense, optionally linked to the obligation instance it
/// settles. `isReconciliation` marks the single adjusting entry produced
/// by UC-09 rather than a normal Quick Add Expense — see R17.
class Expenses extends Table {
  TextColumn get id => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get categoryId =>
      text().references(Categories, #id, onDelete: KeyAction.restrict)();
  TextColumn get instanceId => text().nullable().references(
    ObligationInstances,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get spentAt => dateTime()();
  BoolColumn get isReconciliation =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Single-row settings table. Always exactly one row (id = 0).
class Settings extends Table {
  IntColumn get id => integer()();

  /// Reservation horizon in days — R2. Defaults to 30 per the locked
  /// decision in BACKLOG.md.
  IntColumn get horizonDays => integer().withDefault(const Constant(30))();
  TextColumn get currency => text().withDefault(const Constant('MRU'))();
  DateTimeColumn get expectedNextIncomeDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
