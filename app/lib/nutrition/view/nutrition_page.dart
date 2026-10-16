import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/view/check_in_page.dart'
    show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/add_meal/view/add_meal_page.dart';
import 'package:compound/nutrition/add_meal/view/amount_sheets.dart';
import 'package:compound/nutrition/bloc/nutrition_day_bloc.dart';
import 'package:compound/nutrition/cubit/meal_draft_cubit.dart';
import 'package:compound/nutrition/foods/view/food_detail_page.dart';
import 'package:compound/nutrition/foods/view/foods_page.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/nutrition/logic/meal_logging.dart';
import 'package:compound/nutrition/meal_detail/meal_detail_page.dart';
import 'package:compound/nutrition/recipes/view/recipe_detail_page.dart';
import 'package:compound/nutrition/recipes/view/recipes_page.dart';
import 'package:compound/nutrition/search/nutrition_search_cubit.dart';
import 'package:compound/nutrition/timeline_actions/timeline_actions_sheet.dart';
import 'package:compound/nutrition/view/widgets/calendar_strip.dart';
import 'package:compound/nutrition/view/widgets/macro_header.dart';
import 'package:compound/nutrition/view/widgets/meal_timeline.dart';
import 'package:compound/nutrition_overview/nutrition_overview.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
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
          )..add(const NutritionDaySubscriptionRequested()),
        ),
        BlocProvider(
          create: (context) => NutritionSearchCubit(
            uid: state.user.uid,
            foods: context.read<FoodRepository>(),
          ),
        ),
      ],
      child: const NutritionView(),
    );
  }
}

class NutritionView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<NutritionDayBloc>().state;
    final draft = context.watch<MealDraftCubit>().state;
    final search = context.watch<NutritionSearchCubit>().state;
    return MultiBlocListener(
      listeners: [
        BlocListener<NutritionDayBloc, NutritionDayState>(
          listenWhen: (previous, current) =>
              current.deleteFailures > previous.deleteFailures,
          listener: (context, _) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.nutritionDeleteFailed)),
          ),
        ),
        BlocListener<NutritionDayBloc, NutritionDayState>(
          listenWhen: (previous, current) =>
              current.editFailures > previous.editFailures,
          listener: (context, _) {
            unawaited(HapticFeedback.errorNotification());
            unawaited(
              showFailureAlert(context, context.l10n.nutritionUpdateFoodFailed),
            );
          },
        ),
        BlocListener<NutritionDayBloc, NutritionDayState>(
          listenWhen: (previous, current) =>
              current.logAgainFailures > previous.logAgainFailures,
          listener: (context, _) {
            unawaited(HapticFeedback.errorNotification());
            unawaited(
              showFailureAlert(context, context.l10n.nutritionLogMealFailed),
            );
          },
        ),
        // From another day the copy lands out of sight, on today.
        BlocListener<NutritionDayBloc, NutritionDayState>(
          listenWhen: (previous, current) =>
              current.loggedAgainToday > previous.loggedAgainToday,
          listener: (context, _) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.nutritionLoggedAgainToday)),
          ),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tabNutrition),
          actions: [
            IconButton(
              icon: const Icon(AppSymbols.add),
              tooltip: l10n.nutritionLogMeal,
              onPressed: () => openMealLogger(
                context,
                date: toolbarMealDate(
                  selectedDay: state.selectedDay,
                  now: DateTime.now(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(AppSymbols.analytics),
              tooltip: l10n.nutritionOverviewTitle,
              onPressed: () => context.goNamed(
                NutritionOverviewPage.name,
                queryParameters: {
                  NutritionOverviewPage.dayParameter: dayKeyOf(
                    state.selectedDay,
                  ),
                },
              ),
            ),
            const ProfileButton(),
          ],
        ),
        // The unlogged meal, one tap from being reopened
        // (`MealAccessoryView`).
        bottomNavigationBar: draft == null
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s),
                  child: AppCard(
                    style: AppCardStyle.tile,
                    child: ListTile(
                      leading: const Icon(AppSymbols.meal),
                      title: Text(
                        l10n.nutritionDraftMeal(
                          draft.items.length,
                          AppFormat.kcal(draft.macros.calories.round()),
                        ),
                      ),
                      trailing: const Icon(AppSymbols.disclosure),
                      onTap: () => AddMealPage.show(context, draft),
                    ),
                  ),
                ),
              ),
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
              child: LibrarySearchField(
                key: const Key('Nutrition.search'),
                hint: l10n.nutritionSearchPrompt,
                onChanged: context.read<NutritionSearchCubit>().queryChanged,
              ),
            ),
            Expanded(
              child: search.isSearching
                  ? _SearchResults(state: search)
                  : switch (state.status) {
                      NutritionDayStatus.loading => const Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                      NutritionDayStatus.failure => _Message(
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
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final settings = state.settings!;
    final target = state.target;
    final timeline = state.timeline;
    void select(DateTime day) =>
        context.read<NutritionDayBloc>().add(NutritionDayDateSelected(day));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The strip's cells give only the day and weekday, so the date
        // says which month it is (Swift's navigation subtitle).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat.yMMMd(locale).format(state.selectedDay),
                  style: AppTextStyles.rowDetail.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (state.selectedDay != state.today)
                TextButton(
                  onPressed: () => select(state.today),
                  child: Text(l10n.nutritionToday),
                ),
            ],
          ),
        ),
        if (settings.showCalendarWeekBanner)
          CalendarStrip(
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
                _Message(
                  title: l10n.nutritionNothingLoggedTitle,
                  message: l10n.nutritionNothingLoggedMessage,
                  scrolls: false,
                  // With Hide Empty Hours on there are no hour buttons;
                  // this keeps the day's one job reachable.
                  action: FilledButton(
                    onPressed: () => openMealLogger(
                      context,
                      date: toolbarMealDate(
                        selectedDay: state.selectedDay,
                        now: DateTime.now(),
                      ),
                    ),
                    child: Text(l10n.nutritionLogMeal),
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
                        unawaited(HapticFeedback.successNotification());
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
    unawaited(HapticFeedback.successNotification());
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
      return LibraryEmptyState(
        icon: AppSymbols.search,
        title: l10n.searchNoResults(state.query.trim()),
        message: l10n.searchNoResultsMessage,
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

/// An empty or failed state: the meal glyph, a title and an optional line.
class _Message extends StatelessWidget {
  const new({
    required this.title,
    this.message,
    this.action,
    this.scrolls = true,
  });

  final String title;
  final String? message;
  final Widget? action;

  /// Whether it centres and scrolls itself; false inside a list.
  final bool scrolls;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final message = this.message;
    final column = Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.s,
        children: [
          Icon(
            AppSymbols.meal,
            size: AppIconSize.hero.of(context),
            color: secondary,
          ),
          Text(
            title,
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          if (message != null)
            Text(
              message,
              style: AppTextStyles.rowDetail.copyWith(color: secondary),
              textAlign: TextAlign.center,
            ),
          ?action,
        ],
      ),
    );
    return scrolls
        ? Center(child: SingleChildScrollView(child: column))
        : column;
  }
}
