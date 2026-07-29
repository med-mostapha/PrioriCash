import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prioricash/domain/entities/expense.dart';
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/entities/obligation_instance.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/generated/l10n.dart';
import 'package:prioricash/presentation/providers/providers.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';
import 'package:prioricash/presentation/widgets/primary_action_button.dart';

/// SW-17 — the quick-add-expense form. Traces UC-08.
///
/// Deliberately narrow scope: this screen only records spending
/// (Expense.insert). It never touches ObligationInstance.fundedAmount or
/// re-runs the allocation engine — matching actual spend against an
/// estimated-lump obligation (e.g. Breakfast) is SW-18's job
/// (Reconciliation), not this one. See DOCS.md §4.1.
///
/// All user-facing strings come from S.of(context) — see AGENTS.md §2.6.
class QuickAddExpenseScreen extends ConsumerStatefulWidget {
  const QuickAddExpenseScreen({
    required this.linkableInstances,
    required this.obligationsById,
    super.key,
  });

  /// The same fundable instances HomeScreen already loaded — passed in
  /// rather than re-fetched, so this screen never re-derives what counts
  /// as "current" on its own.
  final List<ObligationInstance> linkableInstances;
  final Map<String, Obligation> obligationsById;

  @override
  ConsumerState<QuickAddExpenseScreen> createState() =>
      _QuickAddExpenseScreenState();
}

class _QuickAddExpenseScreenState extends ConsumerState<QuickAddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  CategoryId _categoryId = CategoryId.food;
  DateTime _spentAt = DateTime.now();
  String? _linkedInstanceId;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickSpentAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _spentAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _spentAt = picked);
  }

  String _instanceLabel(ObligationInstance instance, S l10n) {
    final name =
        widget.obligationsById[instance.obligationId]?.name ??
        instance.obligationId;
    final overdue = instance.isOverdue(DateTime.now());
    final caption = overdue
        ? l10n.overdue
        : l10n.dueInDays(instance.daysUntilDue(DateTime.now()));
    return '$name — $caption';
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final amount = Money.parse(_amountController.text.trim());
    final expense = Expense(
      id: 'expense-${DateTime.now().microsecondsSinceEpoch}',
      categoryId: _categoryId,
      amount: amount,
      spentAt: _spentAt,
      instanceId: _linkedInstanceId,
    );

    await ref.read(expenseRepositoryProvider).insert(expense);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = S.of(context);

    final categoryLabels = <CategoryId, String>{
      CategoryId.food: l10n.categoryFood,
      CategoryId.transport: l10n.categoryTransport,
      CategoryId.utilities: l10n.categoryUtilities,
      CategoryId.health: l10n.categoryHealth,
      CategoryId.other: l10n.categoryOther,
    };

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
                    l10n.quickAddExpense,
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
                      _FieldLabel(l10n.fieldCategory),
                      _SegmentedChoice<CategoryId>(
                        value: _categoryId,
                        options: categoryLabels,
                        onChanged: (value) =>
                            setState(() => _categoryId = value),
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
                      _FieldLabel(l10n.fieldReceivedDate),
                      InkWell(
                        onTap: _pickSpentAt,
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
                            '${_spentAt.year}-${_spentAt.month.toString().padLeft(2, '0')}-${_spentAt.day.toString().padLeft(2, '0')}',
                            style: TextStyle(color: colors.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.gapLarge),
                      _FieldLabel(l10n.fieldLinkToObligation),
                      DropdownButtonFormField<String?>(
                        initialValue: _linkedInstanceId,
                        dropdownColor: colors.background,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: _inputDecoration(colors, ''),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(l10n.linkToObligationNone),
                          ),
                          for (final instance in widget.linkableInstances)
                            DropdownMenuItem<String?>(
                              value: instance.id,
                              child: Text(_instanceLabel(instance, l10n)),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _linkedInstanceId = value),
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
