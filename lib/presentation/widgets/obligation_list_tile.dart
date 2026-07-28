import 'package:flutter/material.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';
import 'package:prioricash/presentation/utils/money_format.dart';

class ObligationListTile extends StatelessWidget {
  const ObligationListTile({
    required this.name,
    required this.dueCaption,
    required this.amount,
    required this.fundedFraction,
    this.isOverdue = false,
    this.isLast = false,
    super.key,
  });

  final String name;

  final String dueCaption;

  final Money amount;

  final double fundedFraction;

  final bool isOverdue;

  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final progressColor = fundedFraction >= 1.0
        ? colors.accent
        : colors.primary;
    final captionColor = isOverdue ? colors.danger : colors.textSecondary;

    return Container(
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.listItemTitle.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.gapTiny),
                Text(
                  dueCaption,
                  style: AppTypography.listItemCaption.copyWith(
                    color: captionColor,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                MoneyFormat.display(amount),
                style: AppTypography.listItemAmount.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: AppSpacing.progressBarRadius,
                child: SizedBox(
                  width: AppSpacing.progressBarWidth,
                  height: AppSpacing.progressBarHeight,
                  child: LinearProgressIndicator(
                    value: fundedFraction.clamp(0.0, 1.0),
                    backgroundColor: colors.progressTrack,
                    valueColor: AlwaysStoppedAnimation(progressColor),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
