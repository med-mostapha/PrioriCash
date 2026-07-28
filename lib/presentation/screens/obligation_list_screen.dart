import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/value_objects/recurrence.dart';
import 'package:prioricash/generated/l10n.dart';
import 'package:prioricash/presentation/providers/providers.dart';
import 'package:prioricash/presentation/screens/obligation_form_screen.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';
import 'package:prioricash/presentation/utils/money_format.dart';

/// SW-14 — obligation management screen. Traces UC-02.
///
/// Lists active obligations, opens ObligationFormScreen via Navigator.push
/// for both create and edit. There is deliberately no delete action here —
/// only deactivate, per R16: an obligation with allocations against its
/// instances is never physically removed.
///
/// All user-facing strings come from S.of(context) — see AGENTS.md §2.6.
class ObligationListScreen extends ConsumerStatefulWidget {
  const ObligationListScreen({super.key});

  @override
  ConsumerState<ObligationListScreen> createState() =>
      _ObligationListScreenState();
}

class _ObligationListScreenState extends ConsumerState<ObligationListScreen> {
  List<Obligation>? _obligations;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final repo = ref.read(obligationRepositoryProvider);
    final result = await repo.getActive();
    result.sort((a, b) => a.name.compareTo(b.name));
    if (!mounted) return;
    setState(() {
      _obligations = result;
      _isLoading = false;
    });
  }

  Future<void> _openForm({Obligation? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ObligationFormScreen(existing: existing),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _deactivate(Obligation obligation) async {
    final repo = ref.read(obligationRepositoryProvider);
    await repo.deactivate(obligation.id);
    await _load();
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        l10n.obligationsTitle,
                        style: AppTypography.summaryValue.copyWith(
                          color: colors.textPrimary,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.add, color: colors.primary),
                    onPressed: () => _openForm(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (_obligations == null || _obligations!.isEmpty)
                  ? Center(
                      child: Text(
                        l10n.noObligationsYet,
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
                        for (var i = 0; i < _obligations!.length; i++)
                          _ObligationRow(
                            obligation: _obligations![i],
                            isLast: i == _obligations!.length - 1,
                            onTap: () => _openForm(existing: _obligations![i]),
                            onDeactivate: () => _deactivate(_obligations![i]),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObligationRow extends StatelessWidget {
  const _ObligationRow({
    required this.obligation,
    required this.isLast,
    required this.onTap,
    required this.onDeactivate,
  });

  final Obligation obligation;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = S.of(context);
    final recurrenceLabel = obligation.recurrence.type == RecurrenceType.weekly
        ? l10n.recurrenceWeekly
        : l10n.recurrenceMonthly;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colors.divider,
              width: AppSpacing.dividerWidth,
            ),
            bottom: isLast
                ? BorderSide(
                    color: colors.divider,
                    width: AppSpacing.dividerWidth,
                  )
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
                  Row(
                    children: [
                      Text(
                        obligation.name,
                        style: AppTypography.listItemTitle.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      if (!obligation.isEssential) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          l10n.discretionary,
                          style: AppTypography.listItemCaption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.gapTiny),
                  Text(
                    recurrenceLabel,
                    style: AppTypography.listItemCaption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              MoneyFormat.display(obligation.amount),
              style: AppTypography.listItemAmount.copyWith(
                color: colors.textPrimary,
              ),
            ),
            IconButton(
              icon: Icon(Icons.archive_outlined, color: colors.textSecondary),
              tooltip: l10n.deactivate,
              onPressed: onDeactivate,
            ),
          ],
        ),
      ),
    );
  }
}
