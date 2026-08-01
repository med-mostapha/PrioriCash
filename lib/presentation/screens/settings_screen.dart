import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prioricash/domain/entities/settings.dart';
import 'package:prioricash/generated/l10n.dart';
import 'package:prioricash/presentation/providers/providers.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';
import 'package:prioricash/presentation/widgets/primary_action_button.dart';
import 'package:prioricash/presentation/widgets/form_field_label.dart';
import 'package:prioricash/presentation/widgets/segmented_choice.dart';

/// SW-20 — Settings screen (R18).
///
/// horizonDays is fully wired: HomeScreen and AddIncomeScreen read it from
/// here instead of a hardcoded constant. currency is stored and shown,
/// but intentionally not yet applied anywhere — see the doc comment on
/// [Settings.currency] for why, and [S.currencyNotYetActiveNote] for the
/// user-facing disclosure.
///
/// All user-facing strings come from S.of(context) — see AGENTS.md §2.6.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _horizonController = TextEditingController();

  CurrencyId _currency = CurrencyId.mru;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    final settings = await repo.getSettings();
    if (!mounted) return;
    setState(() {
      _horizonController.text = '${settings.horizonDays}';
      _currency = settings.currency;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _horizonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    final horizonDays = int.parse(_horizonController.text.trim());
    final repo = ref.read(settingsRepositoryProvider);
    await repo.updateSettings(
      Settings(horizonDays: horizonDays, currency: _currency),
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = S.of(context);

    if (_isLoading) {
      return Material(
        color: colors.background,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final currencyLabels = <CurrencyId, String>{
      for (final c in CurrencyId.values) c: c.code,
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
                    l10n.settingsTitle,
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
                      FormFieldLabel(l10n.fieldHorizonDays),
                      TextFormField(
                        controller: _horizonController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: _inputDecoration(colors),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.validationRequired;
                          }
                          final parsed = int.tryParse(value.trim());
                          if (parsed == null) {
                            return l10n.validationInvalidAmount;
                          }
                          if (parsed <= 0) {
                            return l10n.validationMustBePositive;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.gapLarge),
                      FormFieldLabel(l10n.fieldCurrencyPreference),
                      SegmentedChoice<CurrencyId>(
                        value: _currency,
                        options: currencyLabels,
                        onChanged: (value) => setState(() => _currency = value),
                      ),
                      const SizedBox(height: AppSpacing.gapSmall),
                      Text(
                        l10n.currencyNotYetActiveNote,
                        style: AppTypography.listItemCaption.copyWith(
                          color: colors.textSecondary,
                        ),
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

  InputDecoration _inputDecoration(AppColors colors) {
    return InputDecoration(
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
