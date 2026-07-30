import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prioricash/domain/entities/obligation.dart' show Priority;
import 'package:prioricash/domain/entities/savings_goal.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/generated/l10n.dart';
import 'package:prioricash/presentation/providers/providers.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';
import 'package:prioricash/presentation/widgets/primary_action_button.dart';

/// SW-19 — the add/edit savings-goal form. Pushed via Navigator.push from
/// SavingsGoalListScreen; pops back to it on save. Mirrors
/// ObligationFormScreen's structure exactly.
///
/// All user-facing strings come from S.of(context) — see AGENTS.md §2.6.
class SavingsGoalFormScreen extends ConsumerStatefulWidget {
  const SavingsGoalFormScreen({this.existing, super.key});

  final SavingsGoal? existing;

  @override
  ConsumerState<SavingsGoalFormScreen> createState() =>
      _SavingsGoalFormScreenState();
}

class _SavingsGoalFormScreenState extends ConsumerState<SavingsGoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _currentController;

  late Priority _priority;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _targetController = TextEditingController(
      text: existing == null
          ? ''
          : (existing.targetAmount.minorUnits / Money.minorUnitsPerMajor)
                .toStringAsFixed(2),
    );
    _currentController = TextEditingController(
      text: existing == null
          ? '0'
          : (existing.currentAmount.minorUnits / Money.minorUnitsPerMajor)
                .toStringAsFixed(2),
    );
    _priority = existing?.priority ?? Priority.medium;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final target = Money.parse(_targetController.text.trim());
    final current = Money.parse(_currentController.text.trim());
    final id =
        widget.existing?.id ?? 'goal-${DateTime.now().microsecondsSinceEpoch}';

    final goal = SavingsGoal(
      id: id,
      name: _nameController.text.trim(),
      targetAmount: target,
      currentAmount: current,
      priority: _priority,
    );

    final repo = ref.read(savingsGoalRepositoryProvider);
    await repo.upsert(goal);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = S.of(context);

    return Material(
      color: colors.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.screenPadding,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textPrimary),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _isEditing ? l10n.editSavingsGoal : l10n.newSavingsGoal,
                    style: AppTypography.screenTitle.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(l10n.fieldName),
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: _inputDecoration(colors, ''),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? l10n.validationRequired
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.gapLarge),
                      _FieldLabel(l10n.fieldTargetAmount),
                      TextFormField(
                        controller: _targetController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(color: colors.textPrimary),
                        decoration: _inputDecoration(colors, '0.00'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.validationRequired;
                          }
                          try {
                            final parsed = Money.parse(value.trim());
                            if (parsed.isZero || parsed.isNegative) {
                              return l10n.validationMustBePositive;
                            }
                          } on FormatException {
                            return l10n.validationInvalidAmount;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.gapLarge),
                      _FieldLabel(l10n.fieldCurrentAmount),
                      TextFormField(
                        controller: _currentController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(color: colors.textPrimary),
                        decoration: _inputDecoration(colors, '0.00'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.validationRequired;
                          }
                          try {
                            final parsed = Money.parse(value.trim());
                            if (parsed.isNegative) {
                              return l10n.validationMustBePositive;
                            }
                          } on FormatException {
                            return l10n.validationInvalidAmount;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.gapLarge),
                      _FieldLabel(l10n.fieldPriority),
                      _SegmentedChoice<Priority>(
                        value: _priority,
                        options: {
                          Priority.high: l10n.priorityHigh,
                          Priority.medium: l10n.priorityMedium,
                          Priority.low: l10n.priorityLow,
                        },
                        onChanged: (value) => setState(() => _priority = value),
                      ),
                      const SizedBox(height: AppSpacing.gapSection),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: AppSpacing.screenPadding,
              child: PrimaryActionButton(
                label: _isSaving ? l10n.saving : l10n.save,
                onPressed: _isSaving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(AppColors colors, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.textSecondary),
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
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
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

class _SegmentedChoice<T> extends StatelessWidget {
  const _SegmentedChoice({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Wrap(
      spacing: AppSpacing.sm,
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
