import 'package:flutter/material.dart';
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/entities/obligation_instance.dart';
import 'package:prioricash/domain/services/purchase_advisor.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/generated/l10n.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';
import 'package:prioricash/presentation/utils/money_format.dart';

/// SW-13 UI — the "ask before buying" dialog. Traces UC-?? / R13, R14.
///
/// Pure presentation over the already-tested [PurchaseAdvisor] domain
/// service — this widget never recomputes the available balance itself,
/// it receives [available] (and the same fundable [instances] the
/// allocation engine would use) from HomeScreen's already-loaded
/// snapshot, so the two are always in sync — see the doc comment on
/// [PurchaseAdvisor.evaluate].
///
/// All user-facing strings come from S.of(context) — see AGENTS.md §2.6.
Future<void> showPurchaseAdviceDialog(
  BuildContext context, {
  required Money available,
  required List<ObligationInstance> instances,
  required Map<String, Obligation> obligationsById,
  required DateTime today,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PurchaseAdviceDialog(
      available: available,
      instances: instances,
      obligationsById: obligationsById,
      today: today,
    ),
  );
}

class _PurchaseAdviceDialog extends StatefulWidget {
  const _PurchaseAdviceDialog({
    required this.available,
    required this.instances,
    required this.obligationsById,
    required this.today,
  });

  final Money available;
  final List<ObligationInstance> instances;
  final Map<String, Obligation> obligationsById;
  final DateTime today;

  @override
  State<_PurchaseAdviceDialog> createState() => _PurchaseAdviceDialogState();
}

class _PurchaseAdviceDialogState extends State<_PurchaseAdviceDialog> {
  static const _advisor = PurchaseAdvisor();

  final _priceController = TextEditingController();
  String? _errorText;
  PurchaseVerdict? _verdict;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _check() {
    final input = _priceController.text.trim();
    final l10n = S.of(context);

    if (input.isEmpty) {
      setState(() {
        _errorText = l10n.validationRequired;
        _verdict = null;
      });
      return;
    }

    final Money price;
    try {
      price = Money.parse(input);
    } on FormatException {
      setState(() {
        _errorText = l10n.validationInvalidAmount;
        _verdict = null;
      });
      return;
    }

    if (price.isZero || price.isNegative) {
      setState(() {
        _errorText = l10n.validationMustBePositive;
        _verdict = null;
      });
      return;
    }

    setState(() {
      _errorText = null;
      _verdict = _advisor.evaluate(
        price: price,
        available: widget.available,
        instances: widget.instances,
        obligationsById: widget.obligationsById,
        today: widget.today,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = S.of(context);

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
              l10n.askBeforeBuying,
              style: AppTypography.screenTitle.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.gapLarge),
            TextField(
              controller: _priceController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: colors.textPrimary),
              onSubmitted: (_) => _check(),
              decoration: InputDecoration(
                labelText: l10n.fieldPrice,
                labelStyle: TextStyle(color: colors.textSecondary),
                errorText: _errorText,
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: colors.divider,
                    width: AppSpacing.dividerWidth,
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.primary),
                ),
                errorBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.danger),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.gapLarge),
            if (_verdict != null)
              _VerdictCard(
                verdict: _verdict!,
                obligationsById: widget.obligationsById,
              ),
            if (_verdict != null) const SizedBox(height: AppSpacing.gapLarge),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l10n.close,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _check,
                    child: Text(l10n.check),
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

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.verdict, required this.obligationsById});

  final PurchaseVerdict verdict;
  final Map<String, Obligation> obligationsById;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = S.of(context);

    final (color, title, detail) = switch (verdict.result) {
      PurchaseResult.safe => (
        colors.accent,
        l10n.purchaseVerdictSafeTitle,
        l10n.purchaseVerdictSafeDetail,
      ),
      PurchaseResult.tight => (
        colors.primary,
        l10n.purchaseVerdictTightTitle,
        l10n.purchaseVerdictTightDetail,
      ),
      PurchaseResult.breaksObligations => (
        colors.danger,
        l10n.purchaseVerdictBreaksTitle,
        verdict.affectedInstances.isEmpty
            ? l10n.purchaseVerdictBreaksEmptyDetail
            : l10n.purchaseVerdictBreaksDetail,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              verdict.result == PurchaseResult.breaksObligations
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              color: color,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.gapSmall),
            Text(
              title,
              style: AppTypography.summaryValue.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.gapTiny + 2),
        Text(
          detail,
          style: AppTypography.listItemCaption.copyWith(
            color: colors.textSecondary,
          ),
        ),
        if (verdict.affectedInstances.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.gapMedium),
          for (final instance in verdict.affectedInstances)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.gapSmall),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      obligationsById[instance.obligationId]?.name ??
                          instance.obligationId,
                      style: AppTypography.listItemTitle.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    MoneyFormat.display(instance.remaining()),
                    style: AppTypography.listItemAmount.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
