import 'package:flutter/material.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/generated/l10n.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';
import 'package:prioricash/presentation/utils/money_format.dart';

/// SW-18 — the reconciliation confirmation dialog.
///
/// Shown when the person taps a fully-funded, unpaid instance from
/// HomeScreen's upcoming list. Compares what was estimated (and funded)
/// against what SW-17's Quick Add Expense actually recorded against it,
/// then lets them confirm the money genuinely left the account —
/// ObligationInstanceRepository.markPaid().
///
/// This dialog never computes or mutates a balance itself; it only
/// displays the two numbers HomeScreen already has and delegates the
/// actual persistence to [onConfirmPaid].
Future<void> showReconciliationDialog(
  BuildContext context, {
  required String obligationName,
  required Money estimated,
  required Money actualSpent,
  required Future<void> Function() onConfirmPaid,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ReconciliationDialog(
      obligationName: obligationName,
      estimated: estimated,
      actualSpent: actualSpent,
      onConfirmPaid: onConfirmPaid,
    ),
  );
}

class _ReconciliationDialog extends StatefulWidget {
  const _ReconciliationDialog({
    required this.obligationName,
    required this.estimated,
    required this.actualSpent,
    required this.onConfirmPaid,
  });

  final String obligationName;
  final Money estimated;
  final Money actualSpent;
  final Future<void> Function() onConfirmPaid;

  @override
  State<_ReconciliationDialog> createState() => _ReconciliationDialogState();
}

class _ReconciliationDialogState extends State<_ReconciliationDialog> {
  bool _isConfirming = false;

  Future<void> _confirm() async {
    setState(() => _isConfirming = true);
    await widget.onConfirmPaid();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = S.of(context);

    final difference = widget.estimated.subtract(widget.actualSpent);
    final isSurplus = !difference.isNegative;

    return Dialog(
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
              widget.obligationName,
              style: AppTypography.screenTitle.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.gapLarge),
            _AmountRow(
              label: l10n.reconciliationEstimatedLabel,
              value: widget.estimated,
              colors: colors,
            ),
            const SizedBox(height: AppSpacing.gapSmall),
            _AmountRow(
              label: l10n.reconciliationActualLabel,
              value: widget.actualSpent,
              colors: colors,
            ),
            const SizedBox(height: AppSpacing.gapMedium),
            Text(
              isSurplus
                  ? l10n.reconciliationSurplusLabel
                  : l10n.reconciliationDeficitLabel,
              style: AppTypography.listItemCaption.copyWith(
                color: isSurplus ? colors.accent : colors.danger,
              ),
            ),
            const SizedBox(height: AppSpacing.gapLarge),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isConfirming
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      l10n.close,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _isConfirming ? null : _confirm,
                    child: Text(l10n.markAsPaid),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final Money value;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.listItemCaption.copyWith(
            color: colors.textSecondary,
          ),
        ),
        Text(
          MoneyFormat.display(value),
          style: AppTypography.listItemAmount.copyWith(
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
