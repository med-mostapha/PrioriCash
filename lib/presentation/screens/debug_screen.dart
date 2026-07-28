import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/domain/value_objects/recurrence.dart';
import 'package:prioricash/presentation/providers/providers.dart';
import 'package:prioricash/presentation/screens/home_screen.dart';

/// SW-12 — Debug screen.
///
/// Deliberately minimal and temporary: enter an income, see the resulting
/// allocation and the three balances. Replaced by the real home screen in
/// SW-16, once every acceptance criterion has been proven on-device.
///
/// Seed data (a Wi-Fi and a subscription obligation) is created once on
/// first launch since SW-14 (the real obligation CRUD screen) does not
/// exist yet. This is scaffolding, not a feature — see AGENTS.md §3.2.
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  final _incomeController = TextEditingController();
  String? _log;
  bool _isBusy = false;
  bool _seeded = false;

  static const _horizonDays = 30;

  @override
  void dispose() {
    _incomeController.dispose();
    super.dispose();
  }

  DateTime get _today => DateTime.now();
  DateTime get _horizonEnd => _today.add(const Duration(days: _horizonDays));

  Future<void> _ensureSeeded() async {
    if (_seeded) return;
    final obligationRepo = ref.read(obligationRepositoryProvider);
    final existing = await obligationRepo.getActive();
    if (existing.isEmpty) {
      await obligationRepo.upsert(
        Obligation(
          id: 'seed-wifi',
          name: 'Wi-Fi',
          amount: Money.fromMinor(50000),
          recurrence: const Recurrence(RecurrenceType.monthly),
          priority: Priority.high,
          startDate: DateTime(_today.year, _today.month, 5),
        ),
      );
      await obligationRepo.upsert(
        Obligation(
          id: 'seed-subs',
          name: 'Subscriptions',
          amount: Money.fromMinor(30000),
          recurrence: const Recurrence(RecurrenceType.monthly),
          priority: Priority.medium,
          startDate: DateTime(_today.year, _today.month, 12),
        ),
      );
    }
    _seeded = true;
  }

  Future<void> _recordIncomeAndAllocate() async {
    final input = _incomeController.text.trim();
    if (input.isEmpty) return;

    setState(() => _isBusy = true);
    final buffer = StringBuffer();

    try {
      await _ensureSeeded();

      final incomeAmount = Money.parse(input);
      final incomeId = 'debug-income-${DateTime.now().microsecondsSinceEpoch}';

      final db = ref.read(appDatabaseProvider);
      await db.customStatement(
        "INSERT OR IGNORE INTO income_sources (id, name, type, is_active) "
        "VALUES ('debug-source', 'Debug Entry', 'manual', 1)",
      );
      await db.customStatement(
        "INSERT INTO incomes (id, source_id, amount_minor, received_at, note) "
        "VALUES ('$incomeId', 'debug-source', ${incomeAmount.minorUnits}, "
        "${DateTime.now().millisecondsSinceEpoch}, '')",
      );

      final obligationRepo = ref.read(obligationRepositoryProvider);
      final instanceRepo = ref.read(obligationInstanceRepositoryProvider);
      final goalRepo = ref.read(savingsGoalRepositoryProvider);
      final allocationRepo = ref.read(allocationRepositoryProvider);
      final generator = ref.read(instanceGeneratorProvider);
      final engine = ref.read(allocationEngineProvider);
      final calculator = ref.read(balanceCalculatorProvider);

      final obligations = await obligationRepo.getActive();

      final existing = await instanceRepo.getFundable(_horizonEnd);
      final newInstances = generator.generateAll(
        obligations: obligations,
        horizonEnd: _horizonEnd,
        existing: existing,
      );
      if (newInstances.isNotEmpty) {
        await instanceRepo.insertAll(newInstances);
      }

      final fundable = await instanceRepo.getFundable(_horizonEnd);
      final goals = await goalRepo.getActive();
      final obligationsById = {for (final o in obligations) o.id: o};

      final allocations = engine.allocate(
        incomeId: incomeId,
        incomeAmount: incomeAmount,
        instances: fundable,
        obligationsById: obligationsById,
        goals: goals,
        today: _today,
      );

      buffer.writeln('Income: $incomeAmount');
      buffer.writeln('Allocations: ${allocations.length}');
      for (final a in allocations) {
        buffer.writeln('  -> ${a.targetKind}: ${a.amount}');
      }

      if (allocations.isNotEmpty) {
        await allocationRepo.applyAllocations(allocations);
      }

      final reserved = calculator.reservedAmount(
        instances: await instanceRepo.getFundable(_horizonEnd),
        horizonEnd: _horizonEnd,
      );
      final balanceRepo = ref.read(balanceRepositoryProvider);
      final total = await balanceRepo.getTotalBalance();
      final available = calculator.availableBalance(
        total: total,
        reserved: reserved,
      );

      buffer.writeln();
      buffer.writeln('Total balance:     $total');
      buffer.writeln('Reserved:          $reserved');
      buffer.writeln(
        'Available:         $available'
        '${available.isNegative ? '  \u26A0 NEGATIVE' : ''}',
      );
    } catch (e) {
      buffer.writeln('Error: $e');
    }

    setState(() {
      _log = buffer.toString();
      _isBusy = false;
      _incomeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PrioriCash — Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Preview home screen',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Seeded obligations: Wi-Fi (500 MRU/mo), '
              'Subscriptions (300 MRU/mo).',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _incomeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Income amount (MRU)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isBusy ? null : _recordIncomeAndAllocate,
              child: _isBusy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Record income and allocate'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _log ?? 'No allocation run yet.',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
