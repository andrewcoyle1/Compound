import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/add_meal/view/add_meal_page.dart';
import 'package:compound/nutrition/bloc/nutrition_day_bloc.dart';
import 'package:compound/nutrition/cubit/meal_draft_cubit.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/nutrition/logic/meal_logging.dart';
import 'package:compound/nutrition/view/widgets/calendar_strip.dart';
import 'package:compound/nutrition/view/widgets/macro_header.dart';
import 'package:compound/nutrition/view/widgets/meal_timeline.dart';
import 'package:compound/nutrition_overview/nutrition_overview.dart';
import 'package:compound/profile/profile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    return BlocProvider(
      create: (context) => NutritionDayBloc(
        nutritionRepository: context.read<NutritionRepository>(),
        uid: state.user.uid,
      )..add(const NutritionDaySubscriptionRequested()),
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
    return BlocListener<NutritionDayBloc, NutritionDayState>(
      listenWhen: (previous, current) =>
          current.deleteFailures > previous.deleteFailures,
      listener: (context, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.nutritionDeleteFailed)),
      ),
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
        body: switch (state.status) {
          NutritionDayStatus.loading => const Center(
            child: CircularProgressIndicator.adaptive(),
          ),
          NutritionDayStatus.failure => _Message(
            title: l10n.nutritionDayLoadFailed,
          ),
          NutritionDayStatus.loaded => _Day(state: state),
        },
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
          child: timeline.isEmpty
              ? _Message(
                  title: l10n.nutritionNothingLoggedTitle,
                  message: l10n.nutritionNothingLoggedMessage,
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
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  children: [
                    for (final hour in timeline) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s,
                        ),
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
                                    autoSetCurrentTime:
                                        settings.autoSetCurrentTime,
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
                            onDeleteItem: (item) =>
                                context.read<NutritionDayBloc>().add(
                                  NutritionDayItemDeleted(meal, item.itemId),
                                ),
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// An empty or failed state: the meal glyph, a title and an optional line.
class _Message extends StatelessWidget {
  const new({required this.title, this.message, this.action});

  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final message = this.message;
    return Center(
      child: SingleChildScrollView(
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
      ),
    );
  }
}
