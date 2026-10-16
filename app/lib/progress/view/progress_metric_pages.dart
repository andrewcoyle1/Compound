import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/goal_editing/goal_editing_routes.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/onboarding/view/onboarding_labels.dart';
import 'package:compound/progress/bloc/progress_figures.dart';
import 'package:compound/progress/logic/progress_overview.dart'
    show goalFraction;
import 'package:compound/progress/view/card_charts.dart';
import 'package:compound/progress/view/progress_cards.dart';
import 'package:compound/progress/view/progress_metric_view.dart';
import 'package:compound/progress/view/progress_provider.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/training_analytics/view/workout_consistency_page.dart'
    show ContributionGrid;
import 'package:compound_models/compound_models.dart'
    show BodyMeasurementEntryKeys, WeightGoal;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Insights & Analytics (Swift `InsightsAndAnalyticsView`): workouts,
/// expenditure and energy balance, the weight trend and goal progress,
/// each opening its own screen.
class InsightsPage extends StatelessWidget {
  const new({super.key});

  /// The path under the Progress tab, and the route name.
  static const path = 'insights';
  static const name = 'insightsAndAnalytics';

  @override
  Widget build(BuildContext context) => ProgressProvider(
    screen: 'InsightsAndAnalyticsView',
    child: ProgressSectionsView(
      title: context.l10n.progressInsightsHeader,
      sections: (context, state) {
        final l10n = context.l10n;
        final cards = ProgressCards(context, state);
        return [
          ProgressCardSection(
            header: l10n.insightsActivity,
            cards: [cards.workouts()],
          ),
          ProgressCardSection(
            header: l10n.insightsEnergy,
            info: MethodInfo.energyBalance(l10n),
            cards: [cards.expenditure(), cards.energyBalance()],
          ),
          ProgressCardSection(
            header: l10n.insightsBody,
            info: MethodInfo.weightTrend(l10n),
            cards: [cards.weightTrend()],
          ),
          ProgressCardSection(
            header: l10n.insightsGoals,
            cards: [cards.goalProgress()],
          ),
        ];
      },
    ),
  );
}

/// Habits (Swift `HabitsView`): weighing in, training and food logging over
/// the last 30 days, each opening its consistency grid.
class HabitsPage extends StatelessWidget {
  const new({super.key});

  /// The path under the Progress tab, and the route name.
  static const path = 'habits';
  static const name = 'habits';

  @override
  Widget build(BuildContext context) => ProgressProvider(
    screen: 'HabitsView',
    child: ProgressSectionsView(
      title: context.l10n.progressHabitsHeader,
      sections: (context, state) {
        final l10n = context.l10n;
        final cards = ProgressCards(context, state);
        return [
          ProgressCardSection(
            header: l10n.progressGeneralHeader,
            cards: [cards.weighInHabit()],
          ),
          ProgressCardSection(
            header: l10n.habitsTraining,
            cards: [cards.workoutHabit()],
          ),
          ProgressCardSection(
            header: l10n.progressNutritionHeader,
            cards: [cards.foodLoggingHabit()],
          ),
        ];
      },
    ),
  );
}

/// Every weigh-in on a contribution grid (Swift `WeighInConsistencyView`).
/// Weigh-ins are stored here, so All Recorded Data deletes them, clearing
/// the weight and nothing else logged that day.
class WeighInConsistencyPage extends StatelessWidget {
  const new({this.allData = false, super.key});

  /// The path under the Progress tab, and the route names.
  static const path = 'weigh-in-consistency';
  static const name = 'weighInConsistency';
  static const dataName = 'weighInConsistencyData';

  /// Whether to show every entry instead of the grid.
  final bool allData;

  @override
  Widget build(BuildContext context) => ProgressProvider(
    screen: 'WeighInConsistencyView',
    child: ProgressMetricView(
      allData: allData,
      allDataRoute: dataName,
      metric: (context, state) {
        final l10n = context.l10n;
        final readings = state.weightReadings;
        final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
        return ProgressMetric(
          title: l10n.progressWeighIn,
          unit: state.unit.symbol,
          series: const [],
          entries: [for (final r in readings) (date: r.date, value: r.value)],
          entryIds: [for (final r in readings) r.id],
          deleteFields: const {BodyMeasurementEntryKeys.weightKg},
          emptyMessage: l10n.weighInEmpty,
          add: logWeightAction(context),
          chart: readings.isEmpty
              ? null
              : ContributionGrid(
                  dates: [for (final r in readings) r.date],
                  today: state.today,
                  firstWeekday: firstDay == 0 ? DateTime.sunday : firstDay,
                  color: context.appColors.habits,
                  semanticsLabel: l10n.weighInGridLabel(readings.length),
                  countText: l10n.weighInGridLabel,
                ),
        );
      },
    ),
  );
}

/// The last 90 days' steps, a day keeping its largest reading (Swift
/// `StepsView`). Appearing asks Apple Health or Health Connect for step
/// access and imports; "Sync from Apple Health" does so again on a tap and
/// says when access is refused.
class StepsPage extends StatelessWidget {
  const new({this.allData = false, super.key});

  /// The path under the Progress tab, and the route names.
  static const path = 'steps';
  static const name = 'steps';
  static const dataName = 'stepsData';

  /// Whether to show every entry instead of the chart.
  final bool allData;

  @override
  Widget build(BuildContext context) => ProgressProvider(
    screen: 'StepsView',
    child: BlocListener<HealthCubit, HealthState>(
      listenWhen: (previous, current) =>
          current.stepsAccessFailures > previous.stepsAccessFailures,
      listener: (context, _) => unawaited(showStepsAccessFailed(context)),
      child: OnAppear(
        onAppear: () => unawaited(context.read<HealthCubit>().stepsAppeared()),
        child: ProgressMetricView(
          allData: allData,
          allDataRoute: dataName,
          metric: (context, state) {
            final l10n = context.l10n;
            final locale = Localizations.localeOf(context).toLanguageTag();
            final points = state.stepsHistory;
            return ProgressMetric(
              title: l10n.progressSteps,
              unit: '',
              series: [
                MetricChartSeries(
                  label: l10n.progressSteps,
                  points: points,
                  color: context.appColors.steps,
                  isBar: true,
                ),
              ],
              entries: points,
              entryText: (index) => l10n.stepsEntry(
                AppFormat.number(
                  points[points.length - 1 - index].value,
                  locale: locale,
                ),
              ),
              emptyMessage: l10n.stepsEmpty,
              // Steps cannot be typed in, but they can be fetched again.
              add: ProgressMetricAction(
                label: l10n.healthSync(context),
                icon: AppSymbols.sync,
                onPressed: () =>
                    unawaited(context.read<HealthCubit>().stepsSyncPressed()),
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// Progress toward the weight goal (Swift `GoalProgressView`): how far the
/// trend weight has come from the start to the target, and each weigh-in
/// since the goal was set with the progress it stood at. Change Goal edits
/// or replaces the goal, and Set Goal sets one when there is none.
class GoalProgressPage extends StatelessWidget {
  const new({this.allData = false, super.key});

  /// The path under the Progress tab, and the route names.
  static const path = 'goal-progress';
  static const name = 'goalProgress';
  static const dataName = 'goalProgressData';

  /// Whether to show every entry instead of the bar.
  final bool allData;

  @override
  Widget build(BuildContext context) => ProgressProvider(
    screen: 'GoalProgressView',
    child: ProgressMetricView(
      allData: allData,
      allDataRoute: dataName,
      metric: (context, state) {
        final l10n = context.l10n;
        final locale = Localizations.localeOf(context).toLanguageTag();
        final goal = state.goal;
        final entries = state.goalEntries;
        String weight(double kg) =>
            AppFormat.weight(kg, state.unit, locale: locale);
        final newest = entries.reversed.toList();
        return ProgressMetric(
          title: l10n.progressGoalProgress,
          unit: '%',
          series: const [],
          entries: [
            for (final e in entries) (date: e.date, value: e.progressPercent),
          ],
          entryText: (index) => l10n.goalProgressEntry(
            weight(newest[index].weightKg),
            AppFormat.percent(
              newest[index].progressPercent / 100,
              locale: locale,
            ),
          ),
          emptyMessage: goal == null
              ? l10n.goalProgressNoGoalMessage
              : l10n.goalProgressNoEntries,
          info: MethodInfo.goalProgress(l10n),
          add: goal == null ? null : logWeightAction(context),
          actions: [
            if (goal != null)
              ProgressMetricAction(
                label: l10n.goalProgressChangeGoal,
                icon: AppSymbols.edit,
                onPressed: () => unawaited(openWeightGoal(context, goal)),
              ),
          ],
          chart: goal == null
              ? ProgressMessage(
                  title: l10n.goalProgressNoGoal,
                  message: l10n.goalProgressNoGoalMessage,
                  icon: AppSymbols.goal,
                  action: ProgressMetricAction(
                    label: l10n.goalProgressSetGoal,
                    icon: AppSymbols.goal,
                    onPressed: () => unawaited(openWeightGoal(context, null)),
                  ),
                )
              : GoalProgressHeader(
                  goal: goal,
                  trendKg: state.goalTrendKg,
                  weight: weight,
                ),
        );
      },
    ),
  );
}

/// The goal's objective, how far along it is, a bar, and the start, trend
/// and target weights (Swift `GoalProgressPresenter.customChartView`).
class GoalProgressHeader extends StatelessWidget {
  const new({
    required this.goal,
    required this.trendKg,
    required this.weight,
    super.key,
  });

  /// The goal.
  final WeightGoal goal;

  /// The trend weight now, once weighed since the goal was set.
  final double? trendKg;

  /// A kilogram weight in the user's unit.
  final String Function(double kg) weight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final trend = trendKg;
    final fraction = trend == null ? 0.0 : goalFraction(goal, trend);
    Widget label(String title, double kg) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xxs,
      children: [
        Text(title, style: AppTextStyles.label.copyWith(color: secondary)),
        Text(weight(kg), style: AppTextStyles.rowDetail),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.l,
      children: [
        Text(
          goal.objective.label(l10n),
          style: AppTextStyles.rowDetail.copyWith(color: secondary),
        ),
        Text(
          AppFormat.percent(fraction, locale: locale),
          style: AppTextStyles.metricLarge,
        ),
        SizedBox(
          height: AppSpacing.l,
          child: ProgressBarChart(
            current: fraction * 100,
            maximum: 100,
            target: 100,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            label(l10n.goalProgressStart, goal.startingWeightKg),
            if (trend != null) label(l10n.goalProgressTrend, trend),
            label(l10n.goalProgressTarget, goal.targetWeightKg),
          ],
        ),
      ],
    );
  }
}

/// Log Weight, the action on every weigh-in screen.
ProgressMetricAction logWeightAction(BuildContext context) =>
    ProgressMetricAction(
      label: context.l10n.logWeightTitle,
      icon: AppSymbols.add,
      onPressed: () => unawaited(context.pushNamed<void>(LogWeightPage.name)),
    );
