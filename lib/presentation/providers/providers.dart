import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prioricash/data/database/app_database.dart';
import 'package:prioricash/data/repositories/drift_repositories.dart';
import 'package:prioricash/domain/services/allocation_engine.dart';
import 'package:prioricash/domain/services/balance_calculator.dart';
import 'package:prioricash/domain/services/instance_generator.dart';

/// SW-12 wiring: one shared database, repositories built on top of it, and
/// the three domain services. Kept intentionally simple for the debug
/// screen — a real dependency-injection setup belongs to Sprint 2, once
/// the UI layer is real.

final incomeRepositoryProvider = Provider<DriftIncomeRepository>(
  (ref) => DriftIncomeRepository(ref.watch(appDatabaseProvider)),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final obligationRepositoryProvider = Provider<DriftObligationRepository>(
  (ref) => DriftObligationRepository(ref.watch(appDatabaseProvider)),
);

final obligationInstanceRepositoryProvider =
    Provider<DriftObligationInstanceRepository>(
      (ref) =>
          DriftObligationInstanceRepository(ref.watch(appDatabaseProvider)),
    );

final savingsGoalRepositoryProvider = Provider<DriftSavingsGoalRepository>(
  (ref) => DriftSavingsGoalRepository(ref.watch(appDatabaseProvider)),
);

final allocationRepositoryProvider = Provider<DriftAllocationRepository>(
  (ref) => DriftAllocationRepository(ref.watch(appDatabaseProvider)),
);

final balanceRepositoryProvider = Provider<DriftBalanceRepository>(
  (ref) => DriftBalanceRepository(ref.watch(appDatabaseProvider)),
);

// Domain services are pure and stateless — const instances shared app-wide.
final instanceGeneratorProvider = Provider<InstanceGenerator>(
  (ref) => const InstanceGenerator(),
);
final allocationEngineProvider = Provider<AllocationEngine>(
  (ref) => const AllocationEngine(),
);
final balanceCalculatorProvider = Provider<BalanceCalculator>(
  (ref) => const BalanceCalculator(),
);

final expenseRepositoryProvider = Provider<DriftExpenseRepository>(
  (ref) => DriftExpenseRepository(ref.watch(appDatabaseProvider)),
);

final settingsRepositoryProvider = Provider<DriftSettingsRepository>(
  (ref) => DriftSettingsRepository(ref.watch(appDatabaseProvider)),
);