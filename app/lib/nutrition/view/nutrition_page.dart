import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/view/check_in_page.dart'
    show showFailureAlert;
import 'package:compound/coach/coach.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/notifications/reminder_offer/reminder_offer_scope.dart';
import 'package:compound/nutrition/add_meal/view/add_meal_page.dart';
import 'package:compound/nutrition/add_meal/view/amount_sheets.dart';
import 'package:compound/nutrition/bloc/nutrition_day_bloc.dart';
import 'package:compound/nutrition/foods/view/food_detail_page.dart';
import 'package:compound/nutrition/foods/view/foods_page.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/nutrition/logic/meal_logging.dart';
import 'package:compound/nutrition/meal_detail/meal_detail_page.dart';
import 'package:compound/nutrition/recipes/view/recipe_detail_page.dart';
import 'package:compound/nutrition/recipes/view/recipes_page.dart';
import 'package:compound/nutrition/search/nutrition_search_cubit.dart';
import 'package:compound/nutrition/timeline_actions/timeline_actions_sheet.dart';
import 'package:compound/nutrition/view/widgets/macro_header.dart';
import 'package:compound/nutrition/view/widgets/meal_timeline.dart';
import 'package:compound/nutrition_overview/nutrition_overview.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/review/review_moment.dart';
import 'package:compound/settings/nutrition/view/food_log_settings_page.dart'
    show FoodLogSettingsPage;
import 'package:compound/tips/feature_tips.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound/widgets/calendar/calendar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// The Nutrition tab: one day's meal log (Swift `NutritionView`). A week
/// strip to pick the day, the day's macros against its target, and the
/// meals hour by hour, with + in the toolbar and on each hour to log a meal
/// and a swipe to delete a food.
class NutritionPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    // The router only shows the tabs while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => NutritionDayBloc(
            nutritionRepository: context.read<NutritionRepository>(),
            analyticsRepository: context.read<AnalyticsRepository>(),
            uid: state.user.uid,
            reviews: context.read<ReviewPrompter>(),
          )..add(const NutritionDaySubscriptionRequested()),
        ),
        BlocProvider(
          create: (context) => CalendarHeaderCubit(
            analytics: context.read<AnalyticsRepository>(),
            today: startOfDay(DateTime.now()),
          ),
        ),
        BlocProvider(
          create: (context) => NutritionSearchCubit(
            uid: state.user.uid,
            foods: context.read<FoodRepository>(),
          ),
        ),
      ],
      // Meal reminders are offered on the first visit.
      child: ReminderOfferScope(
        uid: state.user.uid,
        onCreated: (offers) => offers.offerMealRemindersIfNeeded(),
        // Food logged in other apps comes in through Health.
        child: OnAppear(
          onAppear: () =>
              unawaited(context.read<HealthCubit>().nutritionAppeared()),
          child: const ScreenTips(
            screen: 'NutritionView',
            tips: [FeatureTips.mealSwipe],
            child: NutritionView(),
          ),
        ),
      ),
    );
  }
}

class NutritionView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<NutritionDayBloc>().state;
    final search = context.watch<NutritionSearchCubit>().state;
    return MultiBlocListener(
      listeners: [
        BlocListener<NutritionDayBloc, NutritionDayState>(
          listenWhen: (previous, current) =>
              current.deleteFailures > previous.deleteFailures,
          listener: (context, _) => showAppSnackBar(
            context,
            context.l10n.nutritionDeleteFailed,
            style: AppSnackBarStyle.error,
          ),
        ),
        BlocListener<NutritionDayBloc, NutritionDayState>(
          listenWhen: (previous, current) =>
              current.editFailures > previous.editFailures,
          listener: (context, _) {
            unawaited(AppHaptics.error());
            unawaited(
              showFailureAlert(context, context.l10n.nutritionUpdateFoodFailed),
            );
          },
        ),
        BlocListener<NutritionDayBloc, NutritionDayState>(
          listenWhen: (previous, current) =>
              current.logAgainFailures > previous.logAgainFailures,
          listener: (context, _) {
            unawaited(AppHaptics.error());
            unawaited(
              showFailureAlert(context, context.l10n.nutritionLogMealFailed),
            );
          },
        ),
        // From another day the copy lands out of sight, on today.
        BlocListener<NutritionDayBloc, NutritionDayState>(
          listenWhen: (previous, current) =>
              current.loggedAgainToday > previous.loggedAgainToday,
          listener: (context, _) => showAppSnackBar(
            context,
            context.l10n.nutritionLoggedAgainToday,
            style: AppSnackBarStyle.success,
          ),
        ),
      ],
      child: AppScaffold(
        largeTitle: l10n.tabNutrition,
        // Swift's order: the coach, +, the calendar, then the profile.
        actions: [
          AskCoachButton(
            CoachContext(
              kind: CoachContextKind.nutritionDay,
              date: dayKeyOf(state.selectedDay),
              title: AppFormat.date(
                state.selectedDay,
                locale: context.dateLocale,
              ),
            ),
          ),
          AppToolbarButton(
            icon: AppSymbols.add,
            semanticLabel: l10n.nutritionLogMeal,
            onPressed: () => openMealLogger(
              context,
              date: toolbarMealDate(
                selectedDay: state.selectedDay,
                now: DateTime.now(),
              ),
            ),
          ),
          AppToolbarButton(
            icon: AppSymbols.calendar,
            semanticLabel: l10n.calendarShow,
            onPressed: () => unawaited(
              CalendarHeader.showCalendar(
                context,
                today: state.today,
                markers: state.markers,
                selectedDay: state.selectedDay,
                onDaySelected: (day) => context.read<NutritionDayBloc>().add(
                  NutritionDayDateSelected(day),
                ),
              ),
            ),
          ),
          const ProfileButton(),
        ],
        // The search over the user's foods and recipes sits above the day,
        // and its results replace the day while it has a query.
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                0,
              ),
              child: AppSearchField(
                clearLabel: l10n.clearSearch,
                key: const Key('Nutrition.search'),
                hint: l10n.nutritionSearchPrompt,
                onChanged: context.read<NutritionSearchCubit>().queryChanged,
              ),
            ),
            Expanded(
              child: search.isSearching
                  ? _SearchResults(state: search)
                  : switch (state.status) {
                      NutritionDayStatus.loading => AppLoadingView(
                        label: l10n.launchLoading,
                      ),
                      NutritionDayStatus.failure => AppErrorState(
                        title: l10n.nutritionDayLoadFailed,
                      ),
                      NutritionDayStatus.loaded => _Day(state: state),
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const new({required this.state});

  final NutritionDayState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = state.settings!;
    final target = state.target;
    final timeline = state.timeline;
    final firstMeal = timeline.expand((hour) => hour.meals).firstOrNull;
    void select(DateTime day) =>
        context.read<NutritionDayBloc>().add(NutritionDayDateSelected(day));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The strip's cells give only the day and weekday, so the date
        // says which month it is (Swift's navigation subtitle).
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppFormat.date(state.selectedDay, locale: context.dateLocale),
                  style: AppTextStyles.rowDetail.secondary(context),
                ),
              ),
              if (state.selectedDay != state.today)
                AppTextButton(
                  label: l10n.nutritionToday,
                  onPressed: () => select(state.today),
                ),
            ],
          ),
        ),
        if (settings.showCalendarWeekBanner)
          CalendarHeader(
            selectedDay: state.selectedDay,
            today: state.today,
            markers: state.markers,
            onDaySelected: select,
          ),
        if (target != null)
          MacroHeader(totals: state.totals, target: target, settings: settings),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              if (timeline.isEmpty)
                AppEmptyState(
                  icon: AppSymbols.meal,
                  title: l10n.nutritionNothingLoggedTitle,
                  description: l10n.nutritionNothingLoggedMessage,
                  // With Hide Empty Hours on there are no hour buttons;
                  // this keeps the day's one job reachable.
                  actionLabel: l10n.nutritionLogMeal,
                  onAction: () => openMealLogger(
                    context,
                    date: toolbarMealDate(
                      selectedDay: state.selectedDay,
                      now: DateTime.now(),
                    ),
                  ),
                ),
              for (final hour in timeline) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                  child: MealHourHeader(
                    hour: hour.hour,
                    meals: hour.meals,
                    showTotals: settings.showHourlyMacroTotals,
                    onAdd: settings.showAddFoodsButton
                        ? () => openMealLogger(
                            context,
                            date: hourMealDate(
                              hour: hour.hour,
                              now: DateTime.now(),
                              autoSetCurrentTime: settings.autoSetCurrentTime,
                            ),
                          )
                        : null,
                  ),
                ),
                for (final meal in hour.meals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s),
                    child: MealCard(
                      // Log Again has only a swipe and the long press;
                      // the tip points at the day's first food.
                      wrapFirstItem: identical(meal, firstMeal)
                          ? (row) => AppTip(
                              id: FeatureTips.mealSwipe,
                              title: l10n.tipMealSwipeTitle,
                              message: l10n.tipMealSwipeMessage,
                              child: row,
                            )
                          : null,
                      meal: meal,
                      settings: settings,
                      onDeleteItem: (item) => context
                          .read<NutritionDayBloc>()
                          .add(NutritionDayItemDeleted(meal, item.itemId)),
                      onOpenMeal: () =>
                          unawaited(MealDetailPage.show(context, meal)),
                      onEditItem: (item) =>
                          unawaited(_edit(context, meal, item)),
                      onLogAgain: () {
                        unawaited(AppHaptics.success());
                        context.read<NutritionDayBloc>().add(
                          NutritionDayMealLoggedAgain(meal),
                        );
                      },
                    ),
                  ),
              ],
              // The foods and recipes the user has made, otherwise
              // reachable only from inside the meal logger (Swift's Library
              // section).
              const SizedBox(height: AppSpacing.l),
              AppSection(
                header: l10n.nutritionLibraryHeader,
                children: [
                  AppListRowButton(
                    key: const Key('Nutrition.foods'),
                    title: l10n.nutritionFoods,
                    icon: AppSymbols.food,
                    onPressed: () => unawaited(showFoods(context)),
                  ),
                  AppListRowButton(
                    key: const Key('Nutrition.recipes'),
                    title: l10n.nutritionRecipes,
                    icon: AppSymbols.recipe,
                    onPressed: () => unawaited(RecipesPage.show(context)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.l),
              AppSection(
                children: [
                  AppListRowButton(
                    key: const Key('Nutrition.timelineActions'),
                    title: l10n.nutritionTimelineActions,
                    icon: AppSymbols.more,
                    onPressed: () => unawaited(
                      showTimelineActions(context, state.selectedDay),
                    ),
                  ),
                  // A row, as in Swift, rather than a fifth toolbar button.
                  AppListRowButton(
                    key: const Key('Nutrition.overview'),
                    title: l10n.nutritionOverviewTitle,
                    icon: AppSymbols.nutrition,
                    onPressed: () => context.goNamed(
                      NutritionOverviewPage.name,
                      queryParameters: {
                        NutritionOverviewPage.dayParameter: dayKeyOf(
                          state.selectedDay,
                        ),
                      },
                    ),
                  ),
                  // Swift's `onCustomiseFoodLogPressed`, which logs no
                  // event of its own.
                  AppListRowButton(
                    key: const Key('Nutrition.customizeFoodLog'),
                    title: l10n.nutritionCustomizeFoodLog,
                    icon: AppSymbols.settings,
                    onPressed: () =>
                        unawaited(context.pushNamed(FoodLogSettingsPage.name)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The pencil: the amount sheet, then the corrected food written back
  /// into its meal.
  Future<void> _edit(
    BuildContext context,
    MealLogModel meal,
    MealItemModel item,
  ) async {
    final bloc = context.read<NutritionDayBloc>();
    final edited = await showItemAmountSheet(context, item);
    if (edited == null) return;
    unawaited(AppHaptics.success());
    bloc.add(NutritionDayItemEdited(meal, edited));
  }
}

/// The search's results (Swift `NutritionView.searchResults`): recipes,
/// then foods, each opening its detail.
class _SearchResults extends StatelessWidget {
  const new({required this.state});

  final NutritionSearchState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final recipes = state.matchingRecipes;
    final foods = state.matchingFoods;
    if (recipes.isEmpty && foods.isEmpty) {
      return AppEmptyState(
        icon: AppSymbols.search,
        title: l10n.searchNoResults(state.query.trim()),
        description: l10n.searchNoResultsMessage,
      );
    }
    return LibrarySections(
      children: [
        if (recipes.isNotEmpty)
          AppSection(
            header: l10n.nutritionSearchRecipes,
            children: [
              for (final recipe in recipes)
                AppListRowButton(
                  title: recipe.name,
                  subtitle: recipe.description,
                  onPressed: () =>
                      unawaited(RecipeDetailPage.show(context, recipe)),
                ),
            ],
          ),
        if (foods.isNotEmpty)
          AppSection(
            header: l10n.nutritionSearchFoods,
            children: [
              for (final food in foods)
                AppListRowButton(
                  title: food.name,
                  subtitle: food.description,
                  onPressed: () =>
                      unawaited(FoodDetailPage.show(context, food)),
                ),
            ],
          ),
      ],
    );
  }
}
