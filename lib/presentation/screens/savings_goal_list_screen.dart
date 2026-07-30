import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prioricash/domain/entities/savings_goal.dart';
import 'package:prioricash/generated/l10n.dart';
import 'package:prioricash/presentation/providers/providers.dart';
import 'package:prioricash/presentation/screens/savings_goal_form_screen.dart';
import 'package:prioricash/presentation/theme/app_colors.dart';
import 'package:prioricash/presentation/theme/app_spacing.dart';
import 'package:prioricash/presentation/theme/app_typography.dart';
import 'package:prioricash/presentation/widgets/savings_goal_tile.dart';

/// SW-19 — savings-goal management screen.
///
/// Lists active goals, opens SavingsGoalFormScreen via Navigator.push for
/// both create and edit. No delete — only deactivate, same rationale as
/// ObligationListScreen (R16-equivalent: a goal with allocation history
/// is never physically removed).
///
/// All user-facing strings come from S.of(context) — see AGENTS.md §2.6.
class SavingsGoalListScreen extends ConsumerStatefulWidget {
  const SavingsGoalListScreen({super.key});

  @override
  ConsumerState<SavingsGoalListScreen> createState() =>
      _SavingsGoalListScreenState();
}

class _SavingsGoalListScreenState extends ConsumerState<SavingsGoalListScreen> {
  List<SavingsGoal>? _goals;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final repo = ref.read(savingsGoalRepositoryProvider);
    final result = await repo.getActive();
    result.sort((a, b) => a.name.compareTo(b.name));
    if (!mounted) return;
    setState(() {
      _goals = result;
      _isLoading = false;
    });
  }

  Future<void> _openForm({SavingsGoal? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SavingsGoalFormScreen(existing: existing),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _deactivate(SavingsGoal goal) async {
    final repo = ref.read(savingsGoalRepositoryProvider);
    await repo.deactivate(goal.id);
    await _load();
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        l10n.savingsGoalsTitle,
                        style: AppTypography.listScreenTitle.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.add, color: colors.primary),
                    onPressed: () => _openForm(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (_goals == null || _goals!.isEmpty)
                  ? Center(
                      child: Text(
                        l10n.noSavingsGoalsYet,
                        style: AppTypography.listItemCaption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      children: [
                        for (var i = 0; i < _goals!.length; i++)
                          SavingsGoalTile(
                            name: _goals![i].name,
                            targetAmount: _goals![i].targetAmount,
                            currentAmount: _goals![i].currentAmount,
                            isLast: i == _goals!.length - 1,
                            onTap: () => _openForm(existing: _goals![i]),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.archive_outlined,
                                color: colors.textSecondary,
                              ),
                              tooltip: l10n.deactivate,
                              onPressed: () => _deactivate(_goals![i]),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
