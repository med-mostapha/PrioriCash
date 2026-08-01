import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prioricash/domain/entities/income.dart';
import 'package:prioricash/domain/services/allocation_engine.dart';
import 'package:prioricash/generated/l10n.dart';
import 'package:prioricash/presentation/providers/providers.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';
import 'package:prioricash/presentation/utils/money_format.dart';

/// SW-21 — undo-from-UI (UC-04).
///
/// Pure presentation over already-tested domain/data primitives:
/// AllocationEngine.undo() decides what to reverse,
/// AllocationRepository.applyReversal() persists it transactionally
/// (funded/current amounts restored, ledger rows marked isReversed —
/// never deleted, per AGENTS.md §1.4).
///
/// All user-facing strings come from S.of(context) — see AGENTS.md §2.6.
class IncomeHistoryScreen extends ConsumerStatefulWidget {
  const IncomeHistoryScreen({super.key});

  @override
  ConsumerState<IncomeHistoryScreen> createState() =>
      _IncomeHistoryScreenState();
}

class _IncomeHistoryScreenState extends ConsumerState<IncomeHistoryScreen> {
  static const _engine = AllocationEngine();

  List<_IncomeRow>? _rows;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final incomeRepo = ref.read(incomeRepositoryProvider);
    final allocationRepo = ref.read(allocationRepositoryProvider);

    final incomes = await incomeRepo.getAll();
    final rows = <_IncomeRow>[];
    for (final income in incomes) {
      final allocations = await allocationRepo.getByIncome(income.id);
      final hasActive = allocations.any((a) => !a.isReversed);
      rows.add(_IncomeRow(income: income, canUndo: hasActive));
    }

    if (!mounted) return;
    setState(() {
      _rows = rows;
      _isLoading = false;
    });
  }

  Future<void> _confirmAndUndo(Income income) async {
    final l10n = S.of(context);
    final colors = AppColors.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: colors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.buttonRadius,
        ),
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.undoConfirmTitle,
                style: AppTypography.screenTitle.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.gapSmall),
              Text(
                l10n.undoConfirmDetail,
                style: AppTypography.listItemCaption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.gapLarge),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        l10n.close,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.danger,
                      ),
                      child: Text(l10n.undo),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final allocationRepo = ref.read(allocationRepositoryProvider);
    final allocations = await allocationRepo.getByIncome(income.id);
    final reversed = _engine.undo(
      incomeId: income.id,
      allocations: allocations,
    );
    await allocationRepo.applyReversal(reversed);
    await _load();
  }

  String _sourceLabel(IncomeSourceId sourceId, S l10n) {
    return switch (sourceId) {
      IncomeSourceId.grant => l10n.sourceGrant,
      IncomeSourceId.family => l10n.sourceFamily,
      IncomeSourceId.freelance => l10n.sourceFreelance,
      IncomeSourceId.gift => l10n.sourceGift,
      IncomeSourceId.other => l10n.sourceOther,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = S.of(context);

    return Material(
      color: colors.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.screenPadding,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    l10n.incomeHistoryTitle,
                    style: AppTypography.listScreenTitle.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (_rows == null || _rows!.isEmpty)
                  ? Center(
                      child: Text(
                        l10n.noIncomeYet,
                        style: AppTypography.listItemCaption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      children: [
                        for (var i = 0; i < _rows!.length; i++)
                          _buildRow(context, _rows![i], i == _rows!.length - 1),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, _IncomeRow row, bool isLast) {
    final colors = AppColors.of(context);
    final l10n = S.of(context);
    final income = row.income;
    final date =
        '${income.receivedAt.year}-${income.receivedAt.month.toString().padLeft(2, '0')}-${income.receivedAt.day.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.divider, width: AppSpacing.dividerWidth),
          bottom: isLast
              ? BorderSide(color: colors.divider, width: AppSpacing.dividerWidth)
              : BorderSide.none,
        ),
      ),
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MoneyFormat.display(income.amount),
                  style: AppTypography.listItemTitle.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.gapTiny),
                Text(
                  '${_sourceLabel(income.sourceId, l10n)} · $date',
                  style: AppTypography.listItemCaption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (row.canUndo)
            TextButton(
              onPressed: () => _confirmAndUndo(income),
              child: Text(l10n.undo, style: TextStyle(color: colors.danger)),
            )
          else
            Text(
              l10n.alreadyUndone,
              style: AppTypography.listItemCaption.copyWith(
                color: colors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _IncomeRow {
  const _IncomeRow({required this.income, required this.canUndo});
  final Income income;
  final bool canUndo;
}