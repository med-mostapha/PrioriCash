import 'package:flutter/material.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';
import 'package:prioricash/presentation/utils/money_format.dart';

class HeroBalanceText extends StatelessWidget {
  const HeroBalanceText({required this.amount, super.key});

  final Money amount;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final integerColor = amount.isNegative ? colors.danger : colors.textPrimary;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: MoneyFormat.integerPart(amount),
            style: AppTypography.heroBalance.copyWith(color: integerColor),
          ),
          TextSpan(
            text: MoneyFormat.fractionPart(amount),
            style: AppTypography.heroBalanceFraction.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
