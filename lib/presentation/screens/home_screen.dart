import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/entities/obligation_instance.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/generated/l10n.dart';
import 'package:prioricash/presentation/providers/providers.dart';
import 'package:prioricash/presentation/screens/obligation_list_screen.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';
import 'package:prioricash/presentation/utils/money_format.dart';
import 'package:prioricash/presentation/widgets/balance_summary_row.dart';
import 'package:prioricash/presentation/widgets/deficit_warning_badge.dart';
import 'package:prioricash/presentation/widgets/hero_balance_text.dart';
import 'package:prioricash/presentation/widgets/obligation_list_tile.dart';
import 'package:prioricash/presentation/widgets/primary_action_button.dart';
import 'package:prioricash/presentation/widgets/secondary_action_button.dart';
import 'package:prioricash/presentation/screens/add_income_screen.dart';
import 'package:prioricash/presentation/widgets/purchase_advice_dialog.dart';
import 'package:prioricash/presentation/screens/quick_add_expense_screen.dart';
import 'package:prioricash/presentation/widgets/reconciliation_dialog.dart';
import 'package:prioricash/domain/entities/savings_goal.dart';
import 'package:prioricash/presentation/screens/savings_goal_list_screen.dart';
import 'package:prioricash/presentation/widgets/savings_goal_tile.dart';
import 'package:prioricash/presentation/screens/settings_screen.dart';
import 'package:prioricash/presentation/screens/income_history_screen.dart';

/// SW-16 — the home screen. Traces UC-06 (view balances).
///
/// Built entirely from the widgets in lib/presentation/widgets/ and the
/// tokens in lib/presentation/theme/ — no raw colors, sizes, or spacing
/// literals here. See AGENTS.md §2.4.
///
/// All user-facing strings come from S.of(context) — no string literal is
/// shown to the user directly. See AGENTS.md §2.6.
///
/// The root is a Material widget, not ColoredBox or a bare container —
/// see AGENTS.md §2.5.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _HomeSnapshot? _snapshot;
  bool _isLoading = true;
  int _horizonDays = 30; // overwritten by Settings on first load — SW-20

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  DateTime get _today => DateTime.now();
  DateTime get _horizonEnd => _today.add(Duration(days: _horizonDays));

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final settingsRepo = ref.read(settingsRepositoryProvider);
    final settings = await settingsRepo.getSettings();
    _horizonDays = settings.horizonDays;

    final obligationRepo = ref.read(obligationRepositoryProvider);
    final instanceRepo = ref.read(obligationInstanceRepositoryProvider);
    final expenseRepo = ref.read(expenseRepositoryProvider);
    final balanceRepo = ref.read(balanceRepositoryProvider);
    final calculator = ref.read(balanceCalculatorProvider);

    final obligations = await obligationRepo.getActive();
    final goalRepo = ref.read(savingsGoalRepositoryProvider);
    final goals = await goalRepo.getActive();
    final fundable = await instanceRepo.getFundable(_horizonEnd);
    // SW-18: fully funded but not yet confirmed paid — still needs
    // attention (reconciliation) and still reserves whatever hasn't
    // actually been spent yet, so it's fetched and merged alongside the
    // instances that still need money.
    final fundedUnpaid = await instanceRepo.getFundedUnpaid();
    final actualSpentByInstance = await expenseRepo.getTotalsByInstance();
    final total = await balanceRepo.getTotalBalance();

    final reservable = [...fundable, ...fundedUnpaid];
    final reserved = calculator.reservedAmount(
      instances: reservable,
      horizonEnd: _horizonEnd,
      actualSpentByInstance: actualSpentByInstance,
    );
    final available = calculator.availableBalance(
      total: total,
      reserved: reserved,
    );

    final upcoming = [...fundable, ...fundedUnpaid]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    if (!mounted) return;
    setState(() {
      _snapshot = _HomeSnapshot(
        total: total,
        reserved: reserved,
        available: available,
        upcoming: upcoming,
        goals: goals,
        obligationsById: {for (final o in obligations) o.id: o},
        actualSpentByInstance: actualSpentByInstance,
      );
      _isLoading = false;
    });
  }

  Future<void> _openObligations() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ObligationListScreen()),
    );
    await _load();
  }

  Future<void> _openSavingsGoals() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SavingsGoalListScreen()),
    );
    await _load();
  }

  Future<void> _openPurchaseAdvisor() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    await showPurchaseAdviceDialog(
      context,
      available: snapshot.available,
      instances: snapshot.upcoming,
      obligationsById: snapshot.obligationsById,
      today: _today,
    );
  }

  Future<void> _openAddIncome() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AddIncomeScreen()),
    );
    await _load();
  }

  Future<void> _openQuickAddExpense() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => QuickAddExpenseScreen(
          linkableInstances: snapshot.upcoming,
          obligationsById: snapshot.obligationsById,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openReconciliation(ObligationInstance instance) async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final name =
        snapshot.obligationsById[instance.obligationId]?.name ??
        instance.obligationId;
    final actualSpent =
        snapshot.actualSpentByInstance[instance.id] ?? Money.zero;

    await showReconciliationDialog(
      context,
      obligationName: name,
      estimated: instance.amount,
      actualSpent: actualSpent,
      onConfirmPaid: () =>
          ref.read(obligationInstanceRepositoryProvider).markPaid(instance.id),
    );
    await _load();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    await _load();
  }

  Future<void> _openIncomeHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const IncomeHistoryScreen()),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = S.of(context);

    if (_isLoading || _snapshot == null) {
      return Material(
        color: colors.background,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final snapshot = _snapshot!;

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: _openQuickAddExpense,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              _TopBar(
                onRefresh: _load,
                onSettings: _openSettings,
                onIncomeHistory: _openIncomeHistory,
              ),
              const SizedBox(height: AppSpacing.gapSection),
              Text(
                l10n.availableToSpend,
                style: AppTypography.sectionLabel.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.gapTiny + 2),
              HeroBalanceText(amount: snapshot.available),
              const SizedBox(height: AppSpacing.gapTiny + 1),
              Text(
                l10n.afterReserving(MoneyFormat.display(snapshot.reserved)),
                style: AppTypography.heroSubtitle.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              if (snapshot.available.isNegative) ...[
                const SizedBox(height: AppSpacing.gapSmall),
                const DeficitWarningBadge(),
              ],
              const SizedBox(height: AppSpacing.lg),
              Divider(color: colors.divider, height: AppSpacing.dividerWidth),
              const SizedBox(height: AppSpacing.lg),
              BalanceSummaryRow(
                items: [
                  SummaryItem(
                    label: l10n.summaryTotal,
                    value: MoneyFormat.display(snapshot.total),
                  ),
                  SummaryItem(
                    label: l10n.summaryReserved,
                    value: MoneyFormat.display(snapshot.reserved),
                  ),
                  SummaryItem(
                    label: l10n.summaryItems,
                    value: '${snapshot.upcoming.length}',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.gapSection),
              Row(
                children: [
                  Expanded(
                    child: PrimaryActionButton(
                      label: l10n.addIncome,
                      onPressed: _openAddIncome,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SecondaryActionButton(
                      label: l10n.askBeforeBuying,
                      onPressed: _openPurchaseAdvisor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.gapSection),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.upcoming,
                    style: AppTypography.sectionLabel.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: _openObligations,
                    child: Text(
                      l10n.manage,
                      style: AppTypography.topBarDate.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.gapMedium),
              if (snapshot.upcoming.isEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: AppSpacing.lg,
                  ),
                  child: Text(
                    l10n.noObligationsYet,
                    style: AppTypography.listItemCaption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                )
              else
                for (var i = 0; i < snapshot.upcoming.length; i++)
                  _buildTile(
                    context,
                    snapshot.upcoming[i],
                    snapshot.obligationsById,
                    i == snapshot.upcoming.length - 1,
                  ),
              const SizedBox(height: AppSpacing.gapSection),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.savingsGoalsSectionTitle,
                    style: AppTypography.sectionLabel.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: _openSavingsGoals,
                    child: Text(
                      l10n.manage,
                      style: AppTypography.topBarDate.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.gapMedium),
              if (snapshot.goals.isEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: AppSpacing.lg,
                  ),
                  child: Text(
                    l10n.noSavingsGoalsYet,
                    style: AppTypography.listItemCaption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                )
              else
                for (var i = 0; i < snapshot.goals.length; i++)
                  SavingsGoalTile(
                    name: snapshot.goals[i].name,
                    targetAmount: snapshot.goals[i].targetAmount,
                    currentAmount: snapshot.goals[i].currentAmount,
                    isLast: i == snapshot.goals.length - 1,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    ObligationInstance instance,
    Map<String, Obligation> obligationsById,
    bool isLast,
  ) {
    final l10n = S.of(context);
    final overdue = instance.isOverdue(_today);
    final daysUntil = instance.daysUntilDue(_today);

    // SW-18: fully funded but not yet confirmed paid gets its own caption
    // and becomes tappable to open reconciliation — distinct from still
    // being funded (overdue / due in X days).
    final awaitingConfirmation = instance.isFullyFunded && !instance.isPaid;

    final caption = awaitingConfirmation
        ? l10n.awaitingConfirmation
        : overdue
        ? l10n.overdue
        : l10n.dueInDays(daysUntil);

    final fundedFraction = instance.amount.minorUnits == 0
        ? 0.0
        : instance.fundedAmount.minorUnits / instance.amount.minorUnits;

    // Falls back to the raw obligationId only if the parent obligation was
    // deactivated between load and render — should not normally happen
    // since getFundable() and getActive() are read together in _load().
    final name =
        obligationsById[instance.obligationId]?.name ?? instance.obligationId;

    return ObligationListTile(
      name: name,
      dueCaption: caption,
      amount: instance.amount,
      fundedFraction: fundedFraction,
      isOverdue: overdue && !awaitingConfirmation,
      isLast: isLast,
      onTap: awaitingConfirmation ? () => _openReconciliation(instance) : null,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onRefresh,
    required this.onSettings,
    required this.onIncomeHistory,
  });

  final VoidCallback onRefresh;
  final VoidCallback onSettings;
  final VoidCallback onIncomeHistory;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = S.of(context);
    final now = DateTime.now();

    final weekdayNames = [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ];
    final monthNames = [
      l10n.monthJan,
      l10n.monthFeb,
      l10n.monthMar,
      l10n.monthApr,
      l10n.monthMay,
      l10n.monthJun,
      l10n.monthJul,
      l10n.monthAug,
      l10n.monthSep,
      l10n.monthOct,
      l10n.monthNov,
      l10n.monthDec,
    ];

    final dateLabel =
        '${weekdayNames[now.weekday - 1]}, ${now.day} '
        '${monthNames[now.month - 1]}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          dateLabel,
          style: AppTypography.topBarDate.copyWith(color: colors.textSecondary),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.history, color: colors.textSecondary),
              onPressed: onIncomeHistory,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: Icon(Icons.settings_outlined, color: colors.textSecondary),
              onPressed: onSettings,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: onRefresh,
              child: Text(
                l10n.refresh,
                style: AppTypography.topBarDate.copyWith(color: colors.primary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HomeSnapshot {
  const _HomeSnapshot({
    required this.total,
    required this.reserved,
    required this.available,
    required this.upcoming,
    required this.obligationsById,
    required this.actualSpentByInstance,
    required this.goals,
  });

  final Money total;
  final Money reserved;
  final Money available;
  final List<ObligationInstance> upcoming;
  final Map<String, Obligation> obligationsById;
  final List<SavingsGoal> goals;

  final Map<String, Money> actualSpentByInstance;
}
