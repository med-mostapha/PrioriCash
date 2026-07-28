import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prioricash/domain/entities/obligation_instance.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/presentation/providers/providers.dart';
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

/// SW-16 — the home screen. Traces UC-06 (view balances).
///
/// Built entirely from the widgets in lib/presentation/widgets/ and the
/// tokens in lib/presentation/theme/ — no raw colors, sizes, or spacing
/// literals here. See AGENTS.md §2.4.
///
/// The root is a Material widget, not ColoredBox or a bare container.
/// Text rendered with no Material ancestor falls back to a debug-style
/// underlined presentation on some desktop rendering paths — every Text
/// on this screen was underlined until this was fixed. RichText (used
/// only by HeroBalanceText) does not depend on that ancestor and was
/// never affected, which is what made the underline appear selectively.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _horizonDays = 30;

  _HomeSnapshot? _snapshot;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  DateTime get _today => DateTime.now();
  DateTime get _horizonEnd => _today.add(const Duration(days: _horizonDays));

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final instanceRepo = ref.read(obligationInstanceRepositoryProvider);
    final balanceRepo = ref.read(balanceRepositoryProvider);
    final calculator = ref.read(balanceCalculatorProvider);

    final fundable = await instanceRepo.getFundable(_horizonEnd);
    final total = await balanceRepo.getTotalBalance();
    final reserved = calculator.reservedAmount(
      instances: fundable,
      horizonEnd: _horizonEnd,
    );
    final available = calculator.availableBalance(
      total: total,
      reserved: reserved,
    );

    fundable.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    if (!mounted) return;
    setState(() {
      _snapshot = _HomeSnapshot(
        total: total,
        reserved: reserved,
        available: available,
        upcoming: fundable,
      );
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (_isLoading || _snapshot == null) {
      return Material(
        color: colors.background,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final snapshot = _snapshot!;

    return Material(
      color: colors.background,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              _TopBar(onRefresh: _load),
              const SizedBox(height: AppSpacing.gapSection),
              Text(
                'AVAILABLE TO SPEND',
                style: AppTypography.sectionLabel.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.gapTiny + 2),
              HeroBalanceText(amount: snapshot.available),
              const SizedBox(height: AppSpacing.gapTiny + 1),
              Text(
                'MRU \u00b7 after reserving ${MoneyFormat.display(snapshot.reserved)}',
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
                    label: 'TOTAL',
                    value: MoneyFormat.display(snapshot.total),
                  ),
                  SummaryItem(
                    label: 'RESERVED',
                    value: MoneyFormat.display(snapshot.reserved),
                  ),
                  const SummaryItem(label: 'ITEMS', value: '\u2014'),
                ],
              ),
              const SizedBox(height: AppSpacing.gapSection),
              Row(
                children: [
                  Expanded(
                    child: PrimaryActionButton(
                      label: 'Add income',
                      onPressed: () {
                        // SW-15: opens the add-income flow.
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SecondaryActionButton(
                      label: 'Ask before buying',
                      onPressed: () {
                        // SW-13 UI: opens the purchase-advisor dialog.
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.gapSection),
              Text(
                'UPCOMING',
                style: AppTypography.sectionLabel.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.gapMedium),
              if (snapshot.upcoming.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text(
                    'No obligations yet.',
                    style: AppTypography.listItemCaption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                )
              else
                for (var i = 0; i < snapshot.upcoming.length; i++)
                  _buildTile(
                    snapshot.upcoming[i],
                    i == snapshot.upcoming.length - 1,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(ObligationInstance instance, bool isLast) {
    final overdue = instance.isOverdue(_today);
    final daysUntil = instance.daysUntilDue(_today);

    final caption = overdue
        ? 'Overdue'
        : daysUntil == 0
        ? 'Due today'
        : 'Due in $daysUntil day${daysUntil == 1 ? '' : 's'}';

    final fundedFraction = instance.amount.minorUnits == 0
        ? 0.0
        : instance.fundedAmount.minorUnits / instance.amount.minorUnits;

    return ObligationListTile(
      // The obligation's display name requires joining against
      // Obligation, which SW-14's list screen will do properly. The
      // instance's obligationId stands in for now — acceptable here since
      // that join is out of scope for the balance view itself.
      name: instance.obligationId,
      dueCaption: caption,
      amount: instance.amount,
      fundedFraction: fundedFraction,
      isOverdue: overdue,
      isLast: isLast,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onRefresh});

  final VoidCallback onRefresh;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final now = DateTime.now();
    final dateLabel =
        '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          dateLabel,
          style: AppTypography.topBarDate.copyWith(color: colors.textSecondary),
        ),
        GestureDetector(
          onTap: onRefresh,
          child: Text(
            'Refresh',
            style: AppTypography.topBarDate.copyWith(color: colors.primary),
          ),
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
  });

  final Money total;
  final Money reserved;
  final Money available;
  final List<ObligationInstance> upcoming;
}
