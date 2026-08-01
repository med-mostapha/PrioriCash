import 'package:flutter/material.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';

/// A row of ChoiceChips for picking one value from a closed set — shared
/// across every add/edit screen (SW-20, fixing the duplication noted
/// since SW-15).
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: options.entries.map((entry) {
        final selected = entry.key == value;
        return ChoiceChip(
          label: Text(entry.value),
          selected: selected,
          onSelected: (_) => onChanged(entry.key),
          backgroundColor: colors.background,
          selectedColor: colors.primary,
          labelStyle: TextStyle(
            color: selected ? colors.textPrimary : colors.textSecondary,
          ),
          side: BorderSide(
            color: selected ? colors.primary : colors.divider,
            width: AppSpacing.dividerWidth,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.buttonRadius,
          ),
        );
      }).toList(),
    );
  }
}