import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/add_meal/view/add_meal_page.dart';
import 'package:compound/nutrition/cubit/meal_draft_cubit.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The unlogged meal, over the tab bar on every tab: its items and
/// calories, a tap from being reopened (Swift `MealAccessoryView`, the tab
/// view's bottom accessory). Nothing without a draft, or while a workout is
/// under way, whose bar has the place; it goes once the meal is logged or
/// discarded.
class MealDraftBar extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<MealDraftCubit>().state;
    final training = context.select<ActiveWorkoutCubit, bool>(
      (cubit) => cubit.state.isActive && cubit.state.session != null,
    );
    if (draft == null || training) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final count = draft.items.length;
    return Material(
      color: AppColors.tintedSurface(scheme.primary),
      child: Semantics(
        button: true,
        label: l10n.mealDraftLabel(count),
        excludeSemantics: true,
        child: InkWell(
          // The draft as it is now, not when the bar was built.
          onTap: () => _reopen(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppControlSize.row),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.s,
              ),
              child: Row(
                spacing: AppSpacing.m,
                children: [
                  Icon(AppSymbols.meal, color: scheme.primary),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.mealDraftTitle,
                          style: AppTextStyles.sectionTitle.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          l10n.mealDraftDetail(
                            count,
                            AppFormat.kcal(
                              draft.macros.calories.round(),
                              locale: locale,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.rowDetail.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(AppSymbols.disclosure, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _reopen(BuildContext context) {
    final draft = context.read<MealDraftCubit>().state;
    if (draft != null) unawaited(AddMealPage.show(context, draft));
  }
}
