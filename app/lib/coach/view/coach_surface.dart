import 'dart:async';
import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:compound/check_in/check_in.dart' show CheckInPage;
import 'package:compound/expenditure_metric/expenditure_metric.dart'
    show ExpenditureMetric;
import 'package:compound/goal_editing/goal_editing_routes.dart'
    show DietPlanRoute;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/log_weight/log_weight.dart' show LogWeightPage;
import 'package:compound/nutrition/add_meal/view/add_meal_page.dart'
    show AddMealPage;
import 'package:compound/nutrition/logic/meal_day.dart' show Macro;
import 'package:compound/nutrition/view/widgets/macro_header.dart'
    show MacroStyle;
import 'package:compound/progress/view/progress_metric_pages.dart'
    show StepsPage;
import 'package:compound/training_library/view/exercise_detail_page.dart'
    show ExerciseDetailPage;
import 'package:compound/weight_metric/weight_metric.dart' show WeightMetric;
import 'package:compound/workout_tracker/view/start_workout.dart'
    show startWorkout;
import 'package:compound_charts/compound_charts.dart';
import 'package:compound_models/compound_models.dart';
import 'package:go_router/go_router.dart';

/// One of the coach's generative UI blocks, drawn from our own widgets
/// (catalog `compound.coach.v1`, [CoachComponent]): a trend chart, target
/// bars, a stat row, actions or follow-up questions, in a card.
///
/// A block that cannot be drawn (an invalid message, an unknown component,
/// missing data) shows its fallback text instead. A screen reader hears
/// the fallback in place of a chart, bars or figures, and before the
/// buttons of actions and follow-ups.
///
/// A [saved] block, from a chat opened again, is a snapshot: it says the
/// day its values were read.
class CoachSurface extends StatelessWidget {
  const new({
    required this.block,
    required this.onFollowUp,
    this.saved = false,
    super.key,
  });

  final CoachBlock block;

  /// Sends a follow-up question as the next message.
  final ValueChanged<String> onFollowUp;

  /// Whether the block is from a saved chat.
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final component = CoachComponent.of(block);
    final asOf = DateTime.tryParse(block.asOf);
    final interactive =
        component is CoachActions || component is CoachFollowUps;
    final footer = saved && asOf != null
        ? l10n.coachBlockAsOf(AppFormat.date(asOf, locale: context.dateLocale))
        : null;
    // A chart and a day's targets are summaries, each on its own card with
    // the date in its footer; figures are a card each; actions and
    // follow-ups sit on the canvas under the answer, as buttons do.
    return Semantics(
      container: true,
      label: block.fallback,
      excludeSemantics: !interactive,
      child: switch (component) {
        final CoachTrendChart chart => _TrendChart(chart, footer: footer),
        final CoachTargetBars bars => _TargetBars(bars, asOf, footer: footer),
        _ => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.s,
          children: [
            switch (component) {
              CoachStatRow(:final stats) => _StatRow(stats),
              CoachActions(:final actions) => _Actions(actions),
              CoachFollowUps(:final questions) => _FollowUps(
                questions,
                onFollowUp,
              ),
              _ => AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: Text(block.fallback, style: AppTextStyles.rowDetail),
                ),
              ),
            },
            if (footer != null)
              Text(footer, style: AppTextStyles.label.secondary(context)),
          ],
        ),
      },
    );
  }
}

/// [value] in [unit], as the rest of the app writes it; the placeholder
/// when the tools had none. Weights arrive in the unit named.
String _quantity(BuildContext context, double? value, CoachUnit unit) {
  if (value == null) return AppFormat.placeholder;
  final l10n = context.l10n;
  String weight(AppWeightUnit shown, {int digits = 1}) => AppFormat.weight(
    shown == AppWeightUnit.pounds ? value / AppFormat.poundsPerKilogram : value,
    shown,
    maxFractionDigits: digits,
  );
  return switch (unit) {
    CoachUnit.kg => weight(AppWeightUnit.kilograms),
    CoachUnit.lb => weight(AppWeightUnit.pounds),
    CoachUnit.kgPerWeek => l10n.coachBlockPerWeek(
      weight(AppWeightUnit.kilograms, digits: 2),
    ),
    CoachUnit.lbPerWeek => l10n.coachBlockPerWeek(
      weight(AppWeightUnit.pounds, digits: 2),
    ),
    CoachUnit.kcal => AppFormat.kcal(value),
    CoachUnit.g => AppFormat.grams(value),
    CoachUnit.steps => l10n.stepsEntry(AppFormat.number(value)),
  };
}

/// [value] in [unit] as a stat shows it: the number, and the unit for the
/// overline beside it; the placeholder alone when the tools had none.
(String, String?) _figure(BuildContext context, double? value, CoachUnit unit) {
  if (value == null) return (AppFormat.placeholder, null);
  final l10n = context.l10n;
  String number(int digits) =>
      AppFormat.number(value, maxFractionDigits: digits);
  return switch (unit) {
    CoachUnit.kg => (number(1), AppWeightUnit.kilograms.symbol),
    CoachUnit.lb => (number(1), AppWeightUnit.pounds.symbol),
    CoachUnit.kgPerWeek => (
      number(2),
      l10n.coachBlockPerWeek(AppWeightUnit.kilograms.symbol),
    ),
    CoachUnit.lbPerWeek => (
      number(2),
      l10n.coachBlockPerWeek(AppWeightUnit.pounds.symbol),
    ),
    CoachUnit.kcal => (number(0), 'kcal'),
    CoachUnit.g => (number(value.abs() >= 10 ? 0 : 1), 'g'),
    CoachUnit.steps => (number(0), l10n.progressStepsUnit),
  };
}

class _TrendChart extends StatelessWidget {
  const new(this.chart, {this.footer});

  final CoachTrendChart chart;

  /// The day a saved block was read.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final exercise = chart.exerciseName;
    final (title, icon, color) = switch (chart.metric) {
      CoachTrendMetric.weight => (
        l10n.coachBlockWeight,
        AppSymbols.scaleWeight,
        colors.scaleWeight,
      ),
      CoachTrendMetric.expenditure => (
        l10n.coachBlockExpenditure,
        AppSymbols.expenditure,
        colors.expenditure,
      ),
      CoachTrendMetric.steps => (
        l10n.coachBlockSteps,
        AppSymbols.steps,
        colors.steps,
      ),
      CoachTrendMetric.exerciseE1rm => (
        exercise == null
            ? l10n.coachBlockOneRepMax
            : l10n.coachBlockExerciseOneRepMax(exercise),
        AppSymbols.workout,
        colors.exercises,
      ),
    };
    final trend = chart.trend;
    final points = chart.points;
    final latest = (trend ?? points).lastOrNull?.y;
    List<ChartPoint> plotted(List<CoachPoint> points) => [
      for (final p in points) (x: p.x, y: p.y),
    ];
    final days = [
      for (final p in [...points, ...?trend]) p.x,
    ]..sort();
    final bars = chart.metric == CoachTrendMetric.steps;
    final (value, unit) = _figure(context, latest, chart.unit);
    return AppSummaryCard(
      title: title,
      icon: icon,
      tint: color,
      value: value,
      unit: unit,
      footer: footer,
      chart: CartesianChart(
        // Taller with the text, so its labels leave room for the plot.
        height: MediaQuery.textScalerOf(context).scale(AppChartHeight.compact),
        data: ChartData(
          start: days.firstOrNull ?? DateTime(2026),
          end: days.isEmpty
              ? DateTime(2026, 1, 2)
              : DateTime(days.last.year, days.last.month, days.last.day + 1),
          yFit: bars ? ChartYFit.zero : ChartYFit.tight,
          series: [
            // With a trend, the readings are dots under it, as on
            // Weight Trend; alone, they are the line.
            ChartSeries(
              label: title,
              color: color,
              points: plotted(points),
              mark: bars
                  ? ChartMark.bar
                  : trend == null
                  ? ChartMark.line
                  : ChartMark.dot,
            ),
            if (trend != null)
              ChartSeries(
                label: l10n.coachBlockTrend,
                color: color,
                points: plotted(trend),
              ),
          ],
        ),
      ),
    );
  }
}

class _TargetBars extends StatelessWidget {
  const new(this.bars, this.asOf, {this.footer});

  final CoachTargetBars bars;

  /// The day a saved block was read.
  final String? footer;

  /// The day the block was read: the day "today" meant.
  final DateTime? asOf;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final day = bars.day ?? asOf;
    // The day's food: the rows are the hero, each bar in its macro's
    // colour, under the day they cover.
    return AppSummaryCard(
      title: day == null
          ? l10n.tabNutrition
          : AppFormat.date(
              day,
              style: AppDateStyle.weekdayDayMonth,
              locale: context.dateLocale,
            ),
      icon: AppSymbols.meal,
      footer: footer,
      chart: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.m,
        children: [
          for (final row in bars.rows)
            Builder(
              builder: (context) {
                final macro = Macro.values.byName(row.nutrient.name);
                final value = row.value;
                final target = row.target;
                final shown = target == null
                    ? _quantity(context, value, row.unit)
                    : l10n.nutritionMacroConsumed(
                        value == null
                            ? AppFormat.placeholder
                            : AppFormat.number(value),
                        _quantity(context, target, row.unit),
                      );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.xs,
                  children: [
                    Row(
                      spacing: AppSpacing.s,
                      children: [
                        Expanded(
                          child: Text(
                            macro.label(l10n),
                            style: AppTextStyles.rowDetail,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            shown,
                            style: AppTextStyles.rowDetail,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    BulletBar(
                      value: value ?? 0,
                      maximum: math.max(target ?? 0, value ?? 0),
                      target: target,
                      over: target != null && (value ?? 0) > target,
                      color: macro.colour(colors),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const new(this.stats);

  final List<CoachStat> stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final cards = [
      for (final stat in stats)
        Builder(
          builder: (context) {
            final (value, unit) = _figure(context, stat.value, stat.unit);
            final (icon, tint) = switch (stat.key) {
              CoachStatKey.weightTrend ||
              CoachStatKey.weightRatePerWeek ||
              CoachStatKey.goalWeight => (
                AppSymbols.scaleWeight,
                colors.scaleWeight,
              ),
              CoachStatKey.expenditure => (
                AppSymbols.expenditure,
                colors.expenditure,
              ),
              CoachStatKey.calorieTarget || CoachStatKey.todayCalories => (
                AppSymbols.calories,
                colors.calories,
              ),
              CoachStatKey.proteinTarget ||
              CoachStatKey.todayProtein => (AppSymbols.protein, colors.protein),
              CoachStatKey.stepsAverage => (AppSymbols.steps, colors.steps),
              CoachStatKey.exerciseE1rm => (
                AppSymbols.workout,
                colors.exercises,
              ),
            };
            return AppSummaryCard(
              title: switch (stat.key) {
                CoachStatKey.weightTrend => l10n.coachStatWeightTrend,
                CoachStatKey.weightRatePerWeek => l10n.coachStatWeightRate,
                CoachStatKey.goalWeight => l10n.coachStatGoalWeight,
                CoachStatKey.expenditure => l10n.coachStatExpenditure,
                CoachStatKey.calorieTarget => l10n.coachStatCalorieTarget,
                CoachStatKey.proteinTarget => l10n.coachStatProteinTarget,
                CoachStatKey.todayCalories => l10n.coachStatTodayCalories,
                CoachStatKey.todayProtein => l10n.coachStatTodayProtein,
                CoachStatKey.stepsAverage => l10n.coachStatStepsAverage,
                CoachStatKey.exerciseE1rm => switch (stat.exerciseName) {
                  final name? => l10n.coachStatExerciseOneRepMax(name),
                  null => l10n.coachStatOneRepMax,
                },
              },
              icon: icon,
              tint: tint,
              value: value,
              unit: unit,
            );
          },
        ),
    ];
    // Two to a row while each has room for its figure, the last alone
    // across the width; one to a row otherwise, as at large text.
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = (constraints.maxWidth - AppSpacing.s) / 2;
        if (room < MediaQuery.textScalerOf(context).scale(_cardWidth)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.s,
            children: cards,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.s,
          children: [
            for (var i = 0; i < cards.length; i += 2)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.s,
                  children: [
                    for (final card in cards.skip(i).take(2))
                      Expanded(child: card),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// The narrowest a card reads well in, at the default text size.
  static const _cardWidth = 150.0;
}

class _Actions extends StatelessWidget {
  const new(this.actions);

  final List<CoachAction> actions;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.s,
    runSpacing: AppSpacing.s,
    children: [
      for (final action in actions)
        AppCtaButton(
          label: _label(context.l10n, action),
          size: AppCtaSize.compact,
          variant: AppCtaVariant.secondary,
          onPressed: () => _open(context, action),
        ),
    ],
  );

  static String _label(AppLocalizations l10n, CoachAction action) =>
      switch (action.kind) {
        CoachActionKind.logWeight => l10n.coachActionLogWeight,
        CoachActionKind.logMeal => l10n.coachActionLogMeal,
        CoachActionKind.startWorkout => l10n.coachActionStartWorkout,
        CoachActionKind.openExercise => switch (action.exerciseName) {
          final name? => l10n.coachActionOpenNamedExercise(name),
          null => l10n.coachActionOpenExercise,
        },
        CoachActionKind.openMetric => switch (action.metric!) {
          CoachMetric.weight => l10n.coachActionOpenWeight,
          CoachMetric.expenditure => l10n.coachActionOpenExpenditure,
          CoachMetric.steps => l10n.coachActionOpenSteps,
        },
        CoachActionKind.openCheckIn => l10n.coachActionOpenCheckIn,
        CoachActionKind.openDietPlan => l10n.coachActionOpenDietPlan,
      };

  /// Opens the screen: the logs, check-in and diet plan over the coach, so
  /// going back returns to it; a tab's screen (an exercise, a metric) by
  /// going there, since the coach covers the tabs. Nothing is written.
  static void _open(BuildContext context, CoachAction action) {
    void push(String name) => unawaited(context.pushNamed<void>(name));
    switch (action.kind) {
      case CoachActionKind.logWeight:
        push(LogWeightPage.name);
      case CoachActionKind.logMeal:
        push(AddMealPage.name);
      case CoachActionKind.openCheckIn:
        push(CheckInPage.name);
      case CoachActionKind.openDietPlan:
        push(DietPlanRoute.name);
      case CoachActionKind.startWorkout:
        unawaited(startWorkout(context, eventPrefix: 'CoachView_Action'));
      case CoachActionKind.openExercise:
        context.goNamed(
          ExerciseDetailPage.name,
          pathParameters: {ExerciseDetailPage.idParameter: action.exerciseId!},
        );
      case CoachActionKind.openMetric:
        context.goNamed(switch (action.metric!) {
          CoachMetric.weight => WeightMetric.weightTrend.name,
          CoachMetric.expenditure => ExpenditureMetric.expenditure.name,
          CoachMetric.steps => StepsPage.name,
        });
    }
  }
}

class _FollowUps extends StatelessWidget {
  const new(this.questions, this.onFollowUp);

  final List<String> questions;
  final ValueChanged<String> onFollowUp;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: AppSpacing.xs,
    children: [
      Text(
        context.l10n.coachFollowUpsTitle.toUpperCase(),
        style: AppTextStyles.overline.secondary(context),
      ),
      Wrap(
        spacing: AppSpacing.xs,
        children: [
          for (final question in questions)
            AppChip(
              label: question,
              icon: AppSymbols.coach,
              onPressed: () => onFollowUp(question),
            ),
        ],
      ),
    ],
  );
}
