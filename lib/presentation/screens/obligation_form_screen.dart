import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/domain/value_objects/recurrence.dart';
import 'package:prioricash/generated/l10n.dart';
import 'package:prioricash/presentation/providers/providers.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';
import 'package:prioricash/presentation/widgets/primary_action_button.dart';

/// SW-14 — the add/edit obligation form. Pushed via Navigator.push from
/// ObligationListScreen; pops back to it on save.
///
/// When [existing] is null this creates a new obligation with a
/// generated id. When it is provided, the form edits that obligation in
/// place (same id, same historical instances — see R16, obligations with
/// allocations are never deleted, only deactivated).
///
/// All user-facing strings come from S.of(context) — see AGENTS.md §2.6.
class ObligationFormScreen extends ConsumerStatefulWidget {
  const ObligationFormScreen({this.existing, super.key});

  final Obligation? existing;

  @override
  ConsumerState<ObligationFormScreen> createState() =>
      _ObligationFormScreenState();
}

class _ObligationFormScreenState extends ConsumerState<ObligationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  late RecurrenceType _recurrenceType;
  late Priority _priority;
  late bool _isEssential;
  late DateTime _startDate;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _amountController = TextEditingController(
      text: existing == null
          ? ''
          : (existing.amount.minorUnits / Money.minorUnitsPerMajor)
                .toStringAsFixed(2),
    );
    _recurrenceType = existing?.recurrence.type ?? RecurrenceType.monthly;
    _priority = existing?.priority ?? Priority.medium;
    _isEssential = existing?.isEssential ?? true;
    _startDate = existing?.startDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final amount = Money.parse(_amountController.text.trim());
    final id =
        widget.existing?.id ?? 'ob-${DateTime.now().microsecondsSinceEpoch}';

    final obligation = Obligation(
      id: id,
      name: _nameController.text.trim(),
      amount: amount,
      recurrence: Recurrence(_recurrenceType),
      priority: _priority,
      startDate: _startDate,
      isEssential: _isEssential,
    );

    final repo = ref.read(obligationRepositoryProvider);
    await repo.upsert(obligation);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
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
                    _isEditing ? l10n.editObligation : l10n.newObligation,
                    style: AppTypography.summaryValue.copyWith(
                      color: colors.textPrimary,
                      fontSize: 18,
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
                        decoration: _inputDecoration(
                          colors,
                          l10n.fieldNameHint,
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? l10n.validationRequired
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.gapLarge),
                      _FieldLabel(l10n.fieldAmount),
                      TextFormField(
                        controller: _amountController,
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
                      _FieldLabel(l10n.fieldRecurrence),
                      _SegmentedChoice<RecurrenceType>(
                        value: _recurrenceType,
                        options: {
                          RecurrenceType.weekly: l10n.recurrenceWeekly,
                          RecurrenceType.monthly: l10n.recurrenceMonthly,
                        },
                        onChanged: (value) =>
                            setState(() => _recurrenceType = value),
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
                      const SizedBox(height: AppSpacing.gapLarge),
                      _FieldLabel(l10n.fieldStartDate),
                      InkWell(
                        onTap: _pickStartDate,
                        child: Container(
                          padding: const EdgeInsetsDirectional.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: colors.divider,
                                width: AppSpacing.dividerWidth,
                              ),
                            ),
                          ),
                          child: Text(
                            '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                            style: TextStyle(color: colors.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.gapLarge),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _FieldLabel(l10n.fieldEssential),
                          Switch(
                            value: _isEssential,
                            activeThumbColor: colors.primary,
                            onChanged: (value) =>
                                setState(() => _isEssential = value),
                          ),
                        ],
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
