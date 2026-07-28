import 'package:flutter/material.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';

class SummaryItem {
  const SummaryItem({required this.label, required this.value});

  final String label;
  final String value;
}

class BalanceSummaryRow extends StatelessWidget {
  const BalanceSummaryRow({required this.items, super.key});

  final List<SummaryItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Row(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.gapLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: AppTypography.summaryLabel.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.gapTiny),
                Text(
                  item.value,
                  style: AppTypography.summaryValue.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
