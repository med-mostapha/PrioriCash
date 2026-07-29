import 'package:flutter/material.dart';
import 'package:prioricash/generated/l10n.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';

class DeficitWarningBadge extends StatelessWidget {
  const DeficitWarningBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.warning_amber_rounded, size: 14, color: colors.danger),
        const SizedBox(width: 5),
        Text(
          S.of(context).commitmentsExceedBalance,
          style: AppTypography.warning.copyWith(color: colors.danger),
        ),
      ],
    );
  }
}
