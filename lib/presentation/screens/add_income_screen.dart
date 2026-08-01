import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prioricash/domain/entities/income.dart';
import 'package:prioricash/domain/value_objects/money.dart';
import 'package:prioricash/generated/l10n.dart';
import 'package:prioricash/presentation/providers/providers.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';
import 'package:prioricash/presentation/widgets/primary_action_button.dart';
import 'package:prioricash/presentation/widgets/form_field_label.dart';
import 'package:prioricash/presentation/widgets/segmented_choice.dart';

/// SW-15 — the add-income form. Pushed via Navigator.push from HomeScreen;
/// pops back to it on save.
///
/// Runs the full record-income flow that, until now, only existed inside
/// DebugScreen (SW-12): generate any obligation instances still missing up
/// to the reservation horizon, record the income, run the allocation
/// engine, and persist the resulting ledger — all before returning to
/// HomeScreen, which then reloads and shows the updated balances.
///
/// All user-facing strings come from S.of(context) — see AGENTS.md §2.6.
class AddIncomeScreen extends ConsumerStatefulWidget {
  const AddIncomeScreen({super.key});

  @override
  ConsumerState<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends ConsumerState<AddIncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  IncomeSourceId _sourceId = IncomeSourceId.grant;
  DateTime _receivedAt = DateTime.now();
  bool _isSaving = false;
  int _horizonDays = 30; // overwritten by Settings before use — SW-20

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  DateTime get _horizonEnd => DateTime.now().add(Duration(days: _horizonDays));

  Future<void> _pickReceivedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receivedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _receivedAt = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final settingsRepo = ref.read(settingsRepositoryProvider);
    final settings = await settingsRepo.getSettings();
    _horizonDays = settings.horizonDays;

    final amount = Money.parse(_amountController.text.trim());
    final income = Income(
      id: 'income-${DateTime.now().microsecondsSinceEpoch}',
      sourceId: _sourceId,
      amount: amount,
      receivedAt: _receivedAt,
      note: _noteController.text.trim(),
    );

    final incomeRepo = ref.read(incomeRepositoryProvider);
    final obligationRepo = ref.read(obligationRepositoryProvider);
    final instanceRepo = ref.read(obligationInstanceRepositoryProvider);
    final goalRepo = ref.read(savingsGoalRepositoryProvider);
    final allocationRepo = ref.read(allocationRepositoryProvider);
    final generator = ref.read(instanceGeneratorProvider);
    final engine = ref.read(allocationEngineProvider);

    // 1. Persist the income row first — the allocation ledger references
    // incomeId by foreign key, so this must exist before applyAllocations.
    await incomeRepo.insert(income);

    // 2. Same generate -> allocate -> apply sequence as DebugScreen (SW-12),
    // now the real flow instead of scaffolding — see DOCS.md §4.3.
    final obligations = await obligationRepo.getActive();
    final existing = await instanceRepo.getFundable(_horizonEnd);
    final newInstances = generator.generateAll(
      obligations: obligations,
      horizonEnd: _horizonEnd,
      existing: existing,
    );
    if (newInstances.isNotEmpty) {
      await instanceRepo.insertAll(newInstances);
    }

    final fundable = await instanceRepo.getFundable(_horizonEnd);
    final goals = await goalRepo.getActive();
    final obligationsById = {for (final o in obligations) o.id: o};

    final allocations = engine.allocate(
      incomeId: income.id,
      incomeAmount: income.amount,
      instances: fundable,
      obligationsById: obligationsById,
      goals: goals,
      today: DateTime.now(),
    );

    if (allocations.isNotEmpty) {
      await allocationRepo.applyAllocations(allocations);
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = S.of(context);

    final sourceLabels = <IncomeSourceId, String>{
      IncomeSourceId.grant: l10n.sourceGrant,
      IncomeSourceId.family: l10n.sourceFamily,
      IncomeSourceId.freelance: l10n.sourceFreelance,
      IncomeSourceId.gift: l10n.sourceGift,
      IncomeSourceId.other: l10n.sourceOther,
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
                    l10n.addIncome,
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
                      FormFieldLabel(l10n.fieldSource),
                      SegmentedChoice<IncomeSourceId>(
                        value: _sourceId,
                        options: sourceLabels,
                        onChanged: (value) => setState(() => _sourceId = value),
                      ),
                      const SizedBox(height: AppSpacing.gapLarge),
                      FormFieldLabel(l10n.fieldAmount),
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
                      FormFieldLabel(l10n.fieldReceivedDate),
                      InkWell(
                        onTap: _pickReceivedDate,
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
                            '${_receivedAt.year}-${_receivedAt.month.toString().padLeft(2, '0')}-${_receivedAt.day.toString().padLeft(2, '0')}',
                            style: TextStyle(color: colors.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.gapLarge),
                      FormFieldLabel(l10n.fieldNote),
                      TextFormField(
                        controller: _noteController,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: _inputDecoration(colors, ''),
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
