import 'package:flutter/material.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';

/// A small uppercase label above a form field — shared across every
/// add/edit screen (SW-20, fixing the duplication noted since SW-15).
class FormFieldLabel extends StatelessWidget {
  const FormFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: AppTypography.sectionLabel.copyWith(color: colors.textSecondary),
      ),
    );
  }
}