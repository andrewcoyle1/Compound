import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/view/check_in_page.dart'
    show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/nutrition/meal_detail/meal_detail_cubit.dart';
import 'package:compound/nutrition/view/widgets/macro_header.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// A logged meal (Swift `MealDetailView`): its totals and foods, read-only,
/// and Delete. Under the Nutrition tab; the meal is the route's extra when
/// the caller has it, and is kept current by its id.
class MealDetailPage extends StatelessWidget {
  const new({required this.mealId, this.meal, super.key});

  static const path = 'meal/:$idParameter';
  static const name = 'mealDetail';
  static const idParameter = 'mealId';

  /// Opens [meal].
  static Future<void> show(BuildContext context, MealLogModel meal) =>
      context.pushNamed<void>(
        name,
        pathParameters: {idParameter: meal.mealId},
        extra: meal,
      );

  final String mealId;
  final MealLogModel? meal;

  @override
  Widget build(BuildContext context) {
    // The router only shows the tabs while someone is signed in.
    final app = context.read<AppBloc>().state;
    if (app is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => MealDetailCubit(
        uid: app.user.uid,
        mealId: mealId,
        meal: meal,
        nutrition: context.read<NutritionRepository>(),
        analytics: context.read<AnalyticsRepository>(),
      ),
      child: const MealDetailView(),
    );
  }
}

class MealDetailView extends StatelessWidget {
  const new({super.key});

  Future<void> _delete(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<MealDetailCubit>();
    final confirmed = await AppDialog.confirmDestructive(
      context,
      title: l10n.mealDetailDeleteTitle,
      message: l10n.mealDetailDeleteMessage,
      confirmLabel: l10n.mealDetailDeleteConfirm,
    );
    if (confirmed) await cubit.deleteConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<MealDetailCubit>().state;
    final meal = state.meal;
    return MultiBlocListener(
      listeners: [
        BlocListener<MealDetailCubit, MealDetailState>(
          listenWhen: (previous, current) =>
              previous.status != current.status &&
              current.status == MealDetailStatus.deleted,
          listener: (context, _) => context.pop(),
        ),
        BlocListener<MealDetailCubit, MealDetailState>(
          listenWhen: (previous, current) =>
              current.deleteFailures > previous.deleteFailures,
          listener: (context, _) => unawaited(
            showFailureAlert(
              context,
              l10n.mealDetailDeleteFailed,
              l10n.mealDetailTryAgain,
            ),
          ),
        ),
      ],
      child: AppScaffold(
        appBar: AppBar(
          title: Text(l10n.mealDetailTitle),
          actions: [
            if (meal != null)
              AppToolbarButton(
                icon: AppSymbols.delete,
                semanticLabel: l10n.mealDetailDelete,
                onPressed: state.status == MealDetailStatus.idle
                    ? () => unawaited(_delete(context))
                    : null,
              ),
          ],
        ),
        body: switch (meal) {
          _ when !state.loaded => AppLoadingView(label: l10n.launchLoading),
          null => AppEmptyState(
            icon: AppSymbols.meal,
            title: l10n.mealDetailNoItems,
          ),
          final meal => _Meal(meal: meal),
        },
      ),
    );
  }
}

class _Meal extends StatelessWidget {
  const new({required this.meal});

  final MealLogModel meal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final totals = totalsOf([meal]);
    final date = meal.date.toLocal();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        Text(
          AppFormat.dateTime(
            date,
            use24HourFormat: context.use24HourFormat,
            locale: context.dateLocale,
          ),
          style: AppTextStyles.rowTitle.secondary(context),
        ),
        const SizedBox(height: AppSpacing.s),
        // Item nutrients are stored at the amount logged, so the totals are
        // a plain sum (`MealDetailPresenter.macroSummary`).
        AppCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final macro in Macro.values)
                  Expanded(
                    child: AppStat(
                      value: macro == Macro.calories
                          ? AppFormat.number(macro.of(totals).round())
                          : AppFormat.grams(macro.of(totals).round()),
                      label: macro.label(l10n),
                      alignment: CrossAxisAlignment.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        if (meal.items.isEmpty)
          AppEmptyState(
            icon: AppSymbols.meal,
            title: l10n.mealDetailNoItems,
            description: l10n.mealDetailNoItemsMessage,
          )
        else
          AppSection(
            header: l10n.mealDetailItems,
            children: [
              for (final item in meal.items)
                AppListRow(
                  // The food's stand-in picture, as on the Nutrition tab.
                  thumbnail: const Center(
                    child: AppIconBadge(icon: AppSymbols.meal),
                  ),
                  title: item.displayName,
                  subtitle: [
                    AppFormat.kcal(item.macros.calories.round()),
                    l10n.nutritionItemProtein(
                      AppFormat.grams(item.macros.proteinGrams),
                    ),
                    l10n.nutritionItemFat(
                      AppFormat.grams(item.macros.fatGrams),
                    ),
                    l10n.nutritionItemCarbs(
                      AppFormat.grams(item.macros.carbGrams),
                    ),
                    [
                      AppFormat.number(item.amount, maxFractionDigits: 2),
                      item.unit,
                    ].join(' '),
                  ].join(' · '),
                ),
            ],
          ),
      ],
    );
  }
}
