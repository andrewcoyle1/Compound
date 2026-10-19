import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/add_meal/bloc/add_meal_bloc.dart';
import 'package:compound/nutrition/add_meal/logic/nutrient_breakdown.dart';
import 'package:compound/nutrition/add_meal/view/amount_sheets.dart';
import 'package:compound/nutrition/add_meal/view/food_picker.dart';
import 'package:compound/nutrition/cubit/meal_draft_cubit.dart';
import 'package:compound/nutrition/foods/view/create_food_pages.dart'
    show nutrientFieldLabel;
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/nutrition/logic/meal_logging.dart';
import 'package:compound/nutrition/view/widgets/macro_header.dart';
import 'package:compound/shell/app_tab.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// Opens the logger for a meal eaten at [date] (Swift
/// `NutritionPresenter.onLogMealPressed` and `MealHourHeaderPresenter
/// .onAddMealPressed`). With an unlogged meal waiting, asks first whether to
/// carry on with it or start again.
Future<void> openMealLogger(
  BuildContext context, {
  required DateTime date,
}) async {
  final app = context.read<AppBloc>().state;
  if (app is! AppAuthenticated) return;
  final drafts = context.read<MealDraftCubit>();
  final fresh = newMeal(uid: app.user.uid, date: date, mealId: newDocumentId());
  final draft = drafts.state;
  if (draft == null) return await AddMealPage.show(context, fresh);
  final l10n = context.l10n;
  final choice = await showAppDialog<bool>(
    context: context,
    title: l10n.addMealDraftTitle,
    actions: [
      AppDialogAction(
        label: l10n.addMealDraftContinue,
        value: true,
        role: AppDialogRole.preferred,
      ),
      AppDialogAction(
        label: l10n.addMealDraftDiscard,
        value: false,
        role: AppDialogRole.destructive,
      ),
      AppDialogAction(
        label: MaterialLocalizations.of(context).cancelButtonLabel,
        role: AppDialogRole.cancel,
      ),
    ],
  );
  if (choice == null || !context.mounted) return;
  if (!choice) drafts.clear();
  return await AddMealPage.show(context, choice ? draft : fresh);
}

/// Logging a meal (Swift `AddMealView`): the plate, with the food picker
/// over it until something is on it. Opened over the tabs with the meal to
/// build; opened directly (a screenshot hook) it starts a meal now.
class AddMealPage extends StatelessWidget {
  const new({this.meal, super.key});

  static const path = '/log-meal';
  static const name = 'logMeal';

  /// Opens the logger on [meal].
  static Future<void> show(BuildContext context, MealLogModel meal) =>
      context.pushNamed<void>(name, extra: meal);

  final MealLogModel? meal;

  @override
  Widget build(BuildContext context) {
    // The router only shows this page while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => AddMealBloc(
        nutritionRepository: context.read<NutritionRepository>(),
        foodRepository: context.read<FoodRepository>(),
        analyticsRepository: context.read<AnalyticsRepository>(),
        meal:
            meal ??
            newMeal(
              uid: state.user.uid,
              date: DateTime.now(),
              mealId: newDocumentId(),
            ),
      )..add(const AddMealSubscriptionRequested()),
      child: const AddMealView(),
    );
  }
}

class AddMealView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final pickerOpen = context.select<AddMealBloc, bool>(
      (bloc) => bloc.state.pickerOpen,
    );
    return MultiBlocListener(
      listeners: [
        // The plate is kept as a draft as it changes, so closing the logger
        // loses nothing (`AddMealPresenter.mealLog.didSet`).
        BlocListener<AddMealBloc, AddMealState>(
          listenWhen: (previous, current) =>
              previous.meal != current.meal && current.meal.items.isNotEmpty,
          listener: (context, state) =>
              context.read<MealDraftCubit>().keep(state.meal),
        ),
        BlocListener<AddMealBloc, AddMealState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            switch (state.status) {
              case AddMealStatus.saved:
                unawaited(HapticFeedback.successNotification());
                context.read<MealDraftCubit>().clear();
                _dismiss(context);
              case AddMealStatus.discarded:
                context.read<MealDraftCubit>().clear();
                _dismiss(context);
              case AddMealStatus.failure:
                unawaited(HapticFeedback.errorNotification());
                unawaited(
                  showAppDialog<void>(
                    context: context,
                    title: context.l10n.addMealSaveFailedTitle,
                    message: context.l10n.addMealSaveFailedMessage,
                    actions: [
                      AppDialogAction(
                        label: MaterialLocalizations.of(context).okButtonLabel,
                        role: AppDialogRole.preferred,
                      ),
                    ],
                  ),
                );
              case AddMealStatus.editing || AddMealStatus.saving:
                break;
            }
          },
        ),
      ],
      // Back from the picker returns to the plate rather than leaving.
      child: PopScope(
        canPop: !pickerOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            context.read<AddMealBloc>().add(const AddMealPickerClosed());
          }
        },
        child: pickerOpen ? const FoodPickerView() : const _PlateView(),
      ),
    );
  }
}

/// Back to wherever the logger was opened from; to Nutrition when opened
/// directly.
void _dismiss(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppTab.nutrition.path);
  }
}

/// The plate (Swift `AddMealView`'s list): its totals against the day's
/// target, its items, and Add Food.
class _PlateView extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<AddMealBloc>();
    final state = context.watch<AddMealBloc>().state;
    final meal = state.meal;
    final time = TimeOfDay.fromDateTime(meal.date.toLocal());
    return AppScaffold(
      appBar: AppBar(
        // Closing keeps the plate as a draft.
        leading: AppToolbarButton.close(
          semanticLabel: MaterialLocalizations.of(context).closeButtonLabel,
          onPressed: () => _dismiss(context),
        ),
        title: Text(l10n.addMealTitle),
        actions: [
          AppChip(
            icon: AppSymbols.duration,
            label: AppFormat.time(
              meal.date.toLocal(),
              use24HourFormat: context.use24HourFormat,
              locale: context.dateLocale,
            ),
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
                helpText: l10n.addMealTimeTitle,
              );
              if (picked == null) return;
              final day = meal.date.toLocal();
              bloc.add(
                AddMealTimeChanged(
                  DateTime(
                    day.year,
                    day.month,
                    day.day,
                    picked.hour,
                    picked.minute,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.s),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: AppSegmentedControl<NutritionScope>(
              segments: [
                AppSegment(
                  value: NutritionScope.plate,
                  label: l10n.addMealScopePlate,
                ),
                AppSegment(
                  value: NutritionScope.day,
                  label: l10n.addMealScopeDay,
                ),
              ],
              selected: state.scope,
              onChanged: (scope) => bloc.add(AddMealScopeChanged(scope)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.s,
              children: [
                for (final macro in Macro.values)
                  AppStat(
                    // Whole numbers, cut rather than rounded, as Swift's
                    // `Int(_:)`.
                    value: l10n.nutritionMacroConsumed(
                      AppFormat.number(macro.of(state.totals).truncate()),
                      AppFormat.number(macro.of(state.target).truncate()),
                    ),
                    label: macro.label(l10n),
                    size: AppStatSize.small,
                  ),
              ],
            ),
          ),
          AppSection(
            header: l10n.addMealPlate,
            children: [
              if (meal.items.isEmpty) AppListRow(title: l10n.addMealPlateEmpty),
              for (final item in meal.items) _PlateItem(item: item),
              AppListRowButton(
                title: l10n.addMealAddFood,
                icon: AppSymbols.add,
                accessory: null,
                onPressed: () => bloc.add(const AddMealPickerOpened()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _AllNutrients(
            nutrients: scopedNutrients(
              meal,
              state.meals ?? const [],
              state.scope,
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomCta(
        children: [
          AppCtaButton(
            label: l10n.addMealLog,
            isLoading: state.status == AddMealStatus.saving,
            onPressed: meal.items.isEmpty
                ? null
                : () => bloc.add(const AddMealSaveRequested()),
          ),
        ],
      ),
    );
  }
}

/// Show all nutrients: every nutrient the plate's foods record at the
/// chosen scope, by category, values only; only the four macros have
/// targets (Swift `AddMealView`'s `breakdownSection`).
class _AllNutrients extends StatelessWidget {
  const new({required this.nutrients});

  final Map<NutrientKey, double> nutrients;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final secondary = AppTextStyles.rowDetail.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: AppCard(
        child: ExpansionTile(
          key: const Key('AddMeal.allNutrients'),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const Icon(AppSymbols.nutrition),
          title: Text(l10n.addMealShowAllNutrients),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final category in NutrientCategory.values) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.m,
                  AppSpacing.l,
                  AppSpacing.xs,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    nutrientCategoryName(l10n, category),
                    style: AppTextStyles.sectionTitle,
                  ),
                ),
              ),
              if (breakdown(nutrients, category) case final rows
                  when rows.isNotEmpty)
                for (final (key, value) in rows)
                  AppListRow(
                    title: nutrientKeyName(l10n, key),
                    accessory: AppListRowValue(
                      formatNutrient(key, value, locale: locale),
                    ),
                  )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.l,
                    vertical: AppSpacing.s,
                  ),
                  child: Text(
                    l10n.addMealNoneRecorded(
                      nutrientCategoryName(l10n, category).toLowerCase(),
                    ),
                    style: secondary,
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.m),
          ],
        ),
      ),
    );
  }
}

/// A category's heading (Swift `Macros.name`).
String nutrientCategoryName(AppLocalizations l10n, NutrientCategory category) =>
    switch (category) {
      NutrientCategory.protein => l10n.nutrientCategoryProtein,
      NutrientCategory.fat => l10n.nutrientCategoryFat,
      NutrientCategory.carbs => l10n.nutrientCategoryCarbs,
      NutrientCategory.vitamins => l10n.nutrientCategoryVitamins,
      NutrientCategory.minerals => l10n.nutrientCategoryMinerals,
      NutrientCategory.other => l10n.nutrientCategoryOther,
    };

/// A nutrient's name (Swift `NutrientKey.name`).
String nutrientKeyName(AppLocalizations l10n, NutrientKey key) => switch (key) {
  NutrientKey.calories => l10n.foodDetailCalories,
  NutrientKey.protein => l10n.foodFieldProtein,
  NutrientKey.carbs => l10n.foodDetailCarbohydrates,
  NutrientKey.fatTotal => l10n.foodDetailTotalFat,
  NutrientKey.addedSugars => l10n.nutrientAddedSugars,
  NutrientKey.sugar => l10n.nutrientSugar,
  NutrientKey.vitaminB6Mg => l10n.nutrientVitaminB6,
  NutrientKey.vitaminB12Mcg => l10n.nutrientVitaminB12,
  NutrientKey.thiaminMg => l10n.nutrientThiamin,
  NutrientKey.niacinMg => l10n.nutrientNiacin,
  NutrientKey.riboflavinMg => l10n.nutrientRiboflavin,
  NutrientKey.pantothenicAcidMg => l10n.nutrientPantothenicAcid,
  NutrientKey.chlorideMg => l10n.foodDetailChloride,
  NutrientKey.chromiumMcg => l10n.foodDetailChromium,
  NutrientKey.molybdenumMcg => l10n.foodDetailMolybdenum,
  NutrientKey.iodineMcg => l10n.foodDetailIodine,
  NutrientKey.biotinMcg => l10n.nutrientBiotin,
  _ => nutrientFieldLabel(l10n, key),
};

/// A plate item: tap to correct its amount, swipe to take it off.
class _PlateItem extends StatelessWidget {
  const new({required this.item});

  final MealItemModel item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<AddMealBloc>();
    final macros = item.macros;
    Future<void> edit() async {
      final edited = await showItemAmountSheet(context, item);
      if (edited == null) return;
      unawaited(HapticFeedback.successNotification());
      bloc.add(AddMealItemChanged(edited));
    }

    // Swift's two swipe actions, neither on a full swipe.
    return AppSwipeActions(
      trailing: [
        AppSwipeAction(
          label: l10n.nutritionDeleteItem,
          icon: AppSymbols.delete,
          isDestructive: true,
          onPressed: () => bloc.add(AddMealItemRemoved(item.itemId)),
        ),
        AppSwipeAction(
          label: l10n.editorEdit,
          icon: AppSymbols.edit,
          onPressed: () => unawaited(edit()),
        ),
      ],
      trailingFullSwipe: false,
      child: AppListRowButton(
        title: item.displayName,
        subtitle: [
          AppFormat.kcal(macros.calories.round()),
          [
            AppFormat.number(item.amount, maxFractionDigits: 2),
            item.unit,
          ].join(' '),
        ].join(' · '),
        onPressed: () => unawaited(edit()),
      ),
    );
  }
}
