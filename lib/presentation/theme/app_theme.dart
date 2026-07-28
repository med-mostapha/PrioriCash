import 'package:flutter/material.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';

abstract final class AppTheme {
  static ThemeData get dark => _build(AppColors.dark);

  static ThemeData _build(AppColors colors) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.dark(
        surface: colors.background,
        primary: colors.primary,
        error: colors.danger,
      ),
      dividerColor: colors.divider,
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: AppSpacing.dividerWidth,
        space: AppSpacing.dividerWidth,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.textPrimary,
          textStyle: AppTypography.buttonLabel,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.buttonRadius,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.accent,
          side: BorderSide(
            color: colors.divider,
            width: AppSpacing.dividerWidth,
          ),
          textStyle: AppTypography.buttonLabel,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.buttonRadius,
          ),
        ),
      ),
      textTheme: TextTheme(bodyMedium: TextStyle(color: colors.textPrimary)),
    );
  }
}
