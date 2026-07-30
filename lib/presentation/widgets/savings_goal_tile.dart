import 'package:flutter/material.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';

/// SW-19 — a single savings-goal row.
///
/// Used both read-only on HomeScreen (no onTap/trailing) and interactive
/// on SavingsGoalListScreen (onTap opens edit, trailing offers
/// deactivate) — same sharing pattern as ObligationListTile.
class SavingsGoalTile extends StatelessWidget {
  const SavingsGoalTile({
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.isLast = false,
    this.onTap,
    this.trailing,
    super.key,
  });

  final String name;
  final Money targetAmount;
  final Money currentAmount;
  final bool isLast;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fraction = targetAmount.minorUnits == 0
        ? 0.0
        : currentAmount.minorUnits / targetAmount.minorUnits;
    final reached = fraction >= 1.0;
    final percentLabel = '${(fraction.clamp(0.0, 1.0) * 100).round()}%';

    final content = Container(
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
                Text(
                  name,
                  style: AppTypography.listItemTitle.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.gapTiny),
                ClipRRect(
                  borderRadius: AppSpacing.progressBarRadius,
                  child: SizedBox(
                    width: AppSpacing.progressBarWidth,
                    height: AppSpacing.progressBarHeight,
                    child: LinearProgressIndicator(
                      value: fraction.clamp(0.0, 1.0),
                      backgroundColor: colors.progressTrack,
                      valueColor: AlwaysStoppedAnimation(
                        reached ? colors.accent : colors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            percentLabel,
            style: AppTypography.listItemCaption.copyWith(
              color: colors.textSecondary,
            ),
          ),
          ?trailing,
        ],
      ),
    );

    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}
