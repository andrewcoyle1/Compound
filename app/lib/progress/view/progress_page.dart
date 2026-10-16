import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/log_measurement/log_measurement.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/progress/bloc/progress_bloc.dart';
import 'package:compound/progress/logic/body_metrics.dart';
import 'package:compound/progress/logic/progress_overview.dart';
import 'package:compound/progress/view/body_metrics_pages.dart';
import 'package:compound/progress/view/nutrition_analytics_pages.dart';
import 'package:compound/progress/view/progress_cards.dart';
import 'package:compound/progress/view/progress_carousel.dart';
import 'package:compound/progress/view/progress_metric_pages.dart';
import 'package:compound/progress/view/progress_names.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/settings/general/view/customise_analytics_page.dart';
import 'package:compound/training_analytics/training_analytics.dart';
import 'package:compound/weekly_review/weekly_review.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart'
    show UnitPreferenceStore;
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// The Progress tab (Swift `AnalyticsView`): the header carousel, then the
/// cards in the Swift sections, honouring the sections the user has hidden,
/// each section's See All opening its own screen, and the More list.
class ProgressPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    // The router only shows the tabs while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    // The locale's first day of the week (0 = Sunday), as Today uses.
    final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    return BlocProvider(
      create: (context) => ProgressBloc(
        workoutSessionRepository: context.read<WorkoutSessionRepository>(),
        nutritionRepository: context.read<NutritionRepository>(),
        bodyRepository: context.read<BodyRepository>(),
        userRepository: context.read<UserRepository>(),
        analyticsRepository: context.read<AnalyticsRepository>(),
        trainingLibraryRepository: context.read<TrainingLibraryRepository>(),
        checkInRepository: context.read<CheckInRepository>(),
        uid: state.user.uid,
        firstWeekday: firstDay == 0 ? DateTime.sunday : firstDay,
        units: context.read<UnitPreferenceStore>(),
      )..add(const ProgressSubscriptionRequested()),
      child: const ProgressView(),
    );
  }
}

class ProgressView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ProgressBloc>().state;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabProgress),
        actions: const [_LogMenu(), ProfileButton()],
      ),
      body: switch (state.status) {
        ProgressStatus.loading => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        ProgressStatus.failure => const _LoadFailure(),
        ProgressStatus.loaded => _Overview(state: state),
      },
    );
  }
}

class _Overview extends StatelessWidget {
  const new({required this.state});

  final ProgressState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cards = ProgressCards(context, state);
    void open(String name) => context.goNamed(name);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          // The grids add columns with width, so this tab takes more of a
          // wide window than a routed screen's column.
          constraints: const BoxConstraints(
            maxWidth: AppContentWidth.dashboard,
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
            children: [
              // Not hideable: the summary at the top.
              ProgressCarousel(state: state),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final section in ProgressSection.values)
                      if (state.isVisible(section))
                        switch (section) {
                          ProgressSection.insightsAndAnalytics =>
                            ProgressCardSection(
                              header: l10n.progressInsightsHeader,
                              onSeeAll: () => open(InsightsPage.name),
                              cards: [
                                cards.workouts(),
                                cards.expenditure(),
                                cards.weightTrend(),
                                cards.goalProgress(),
                                cards.energyBalance(),
                              ],
                            ),
                          ProgressSection.habits => ProgressCardSection(
                            header: l10n.progressHabitsHeader,
                            onSeeAll: () => open(HabitsPage.name),
                            cards: [cards.weighInHabit(), cards.workoutHabit()],
                          ),
                          ProgressSection.nutrition => ProgressCardSection(
                            header: l10n.progressNutritionHeader,
                            onSeeAll: () => open(NutritionAnalyticsPage.name),
                            cards: [cards.macros(), cards.protein()],
                          ),
                          ProgressSection.bodyMetrics => ProgressCardSection(
                            header: l10n.progressBodyMetricsHeader,
                            onSeeAll: () => open(BodyMetricsPage.name),
                            cards: [cards.scaleWeight(), cards.bodyFat()],
                          ),
                          ProgressSection.muscleGroups => ProgressCardSection(
                            header: l10n.progressMuscleGroups,
                            info: MethodInfo.weeklyHardSets(l10n),
                            onSeeAll: () => open(MuscleGroupsPage.name),
                            cards: [
                              for (final muscle in topMuscles(
                                state.muscleLastSevenDays,
                              ))
                                MuscleSetsCard(
                                  muscle: muscle,
                                  lastSevenDays:
                                      state.muscleLastSevenDays[muscle]!,
                                ),
                            ],
                          ),
                          ProgressSection.exercises => ProgressCardSection(
                            header: l10n.progressExercises,
                            info: MethodInfo.estimatedOneRepMax(l10n),
                            onSeeAll: () => open(ExerciseAnalyticsPage.name),
                            cards: [
                              for (final card in state.topExercises)
                                ExerciseOneRepMaxCard(
                                  card: card,
                                  usesPounds:
                                      state.unit == AppWeightUnit.pounds,
                                ),
                            ],
                          ),
                        },
                    // Not hideable in Swift either.
                    ProgressCardSection(
                      header: l10n.progressGeneralHeader,
                      cards: [cards.steps()],
                    ),
                    _More(state: state),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The More list (Swift `moreSection`): every hidden section, so hiding one
/// never makes it unreachable, then Weekly Review and Customize Analytics.
class _More extends StatelessWidget {
  const new({required this.state});

  final ProgressState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppSection(
      header: l10n.progressMore,
      children: [
        for (final section in ProgressSection.values)
          if (!state.isVisible(section))
            AppListRowButton(
              title: switch (section) {
                ProgressSection.insightsAndAnalytics =>
                  l10n.progressInsightsHeader,
                ProgressSection.habits => l10n.progressHabitsHeader,
                ProgressSection.nutrition => l10n.progressNutritionHeader,
                ProgressSection.bodyMetrics => l10n.progressBodyMetricsHeader,
                ProgressSection.muscleGroups => l10n.progressMuscleGroups,
                ProgressSection.exercises => l10n.progressExercises,
              },
              icon: switch (section) {
                ProgressSection.insightsAndAnalytics => AppSymbols.analytics,
                ProgressSection.habits => AppSymbols.habits,
                ProgressSection.nutrition => AppSymbols.nutrition,
                ProgressSection.bodyMetrics => AppSymbols.measurement,
                ProgressSection.muscleGroups => AppSymbols.muscleGroup,
                ProgressSection.exercises => AppSymbols.exercise,
              },
              onPressed: () => context.goNamed(switch (section) {
                ProgressSection.insightsAndAnalytics => InsightsPage.name,
                ProgressSection.habits => HabitsPage.name,
                ProgressSection.nutrition => NutritionAnalyticsPage.name,
                ProgressSection.bodyMetrics => BodyMetricsPage.name,
                ProgressSection.muscleGroups => MuscleGroupsPage.name,
                ProgressSection.exercises => ExerciseAnalyticsPage.name,
              }),
            ),
        AppListRowButton(
          title: l10n.weeklyReviewTitle,
          icon: AppSymbols.weeklyReview,
          onPressed: () => context.goNamed(WeeklyReviewPage.name),
        ),
        AppListRowButton(
          title: l10n.progressCustomizeAnalytics,
          icon: AppSymbols.filter,
          onPressed: () =>
              unawaited(context.pushNamed<void>(CustomiseAnalyticsPage.name)),
        ),
      ],
    );
  }
}

/// The + menu (Swift's toolbar menu): Log Weight, and every circumference
/// grouped as Body Metrics groups them, each opening its logger at once.
class _LogMenu extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(AppSymbols.scaleWeight),
          onPressed: () =>
              unawaited(context.pushNamed<void>(LogWeightPage.name)),
          child: Text(l10n.logWeightTitle),
        ),
        SubmenuButton(
          leadingIcon: const Icon(AppSymbols.measurement),
          menuChildren: [
            for (final group in BodyMetricsGroup.values)
              if (group.kinds.isNotEmpty) ...[
                // A heading, as Swift's menu sections.
                MenuItemButton(
                  child: Text(
                    bodyMetricsGroupName(l10n, group),
                    style: AppTextStyles.label,
                  ),
                ),
                for (final kind in group.kinds)
                  MenuItemButton(
                    onPressed: () =>
                        unawaited(LogMeasurementPage.show(context, kind)),
                    child: Text(bodyMeasurementName(l10n, kind)),
                  ),
              ],
          ],
          child: Text(l10n.progressLogMeasurement),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        icon: const Icon(AppSymbols.add),
        tooltip: l10n.progressLogBodyMetrics,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// The overview could not be read: the Progress glyph and a line saying so.
class _LoadFailure extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.s,
          children: [
            Icon(
              AppSymbols.analytics,
              size: AppIconSize.hero.of(context),
              color: secondary,
            ),
            Text(
              context.l10n.progressLoadFailure,
              style: AppTextStyles.sectionTitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
