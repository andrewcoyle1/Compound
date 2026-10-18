import 'package:app_ui/app_ui.dart';
import 'package:compound/expenditure/expenditure.dart';
import 'package:compound/expenditure_metric/expenditure_metric.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/progress/bloc/progress_bloc.dart';
import 'package:compound/progress/bloc/progress_figures.dart';
import 'package:compound/progress/logic/body_metrics.dart';
import 'package:compound/progress/logic/nutrition_analytics.dart';
import 'package:compound/progress/logic/progress_overview.dart';
import 'package:compound/progress/view/body_metrics_pages.dart';
import 'package:compound/progress/view/card_charts.dart';
import 'package:compound/progress/view/nutrition_analytics_pages.dart';
import 'package:compound/progress/view/progress_card.dart';
import 'package:compound/progress/view/progress_metric_pages.dart';
import 'package:compound/progress/view/progress_metric_view.dart';
import 'package:compound/progress/view/progress_names.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/training_analytics/training_analytics.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:compound_maths/compound_maths.dart'
    show BodyRatioKind, Macros, loggedAverage;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Builds each card from the state (Swift `AnalyticsPresenter`'s text
/// properties). A missing figure reads as the placeholder, never 0.
class ProgressCards {
  new(BuildContext context, this.state)
    : l10n = context.l10n,
      colors = context.appColors,
      accent = Theme.of(context).colorScheme.primary,
      router = GoRouter.maybeOf(context),
      locale = Localizations.localeOf(context).toLanguageTag();

  final ProgressState state;
  final AppLocalizations l10n;
  final AppColors colors;
  final Color accent;
  final GoRouter? router;
  final String locale;

  String _number(num value, [int decimals = 0]) =>
      AppFormat.number(value, maxFractionDigits: decimals, locale: locale);

  /// A line card over [points], headlined by the latest.
  Widget _sparkline({
    required String title,
    required String subtitle,
    required List<ProgressPoint> points,
    required String unit,
    required Color color,
    int decimals = 1,
    VoidCallback? onTap,
    String? value,
  }) {
    String text(double v) => '${_number(v, decimals)} $unit';
    return ProgressCard(
      title: title,
      subtitle: subtitle,
      value:
          value ??
          (points.isEmpty
              ? AppFormat.placeholder
              : _number(points.last.value, decimals)),
      unit: unit,
      onTap: onTap,
      chart: Sparkline(
        points: points,
        color: color,
        semanticsValue: points.isEmpty
            ? null
            : l10n.progressTrendChartValue(
                text(points.first.value),
                text(points.last.value),
              ),
      ),
    );
  }

  Widget workouts() {
    final values = [for (final point in state.workoutSets) point.value];
    final total = values.fold<double>(0, (a, b) => a + b);
    final most = values.fold<double>(0, (a, b) => a > b ? a : b);
    return ProgressCard(
      title: l10n.progressWorkouts,
      subtitle: values.isEmpty
          ? l10n.progressNoWorkouts
          : l10n.progressLast7Workouts,
      value: total > 0 ? _number(total) : AppFormat.placeholder,
      unit: l10n.progressSetsUnit,
      onTap: () => router?.goNamed(WorkoutMetricPage.name),
      chart: StackedBars(
        stacks: [
          for (final v in values) [v],
        ],
        colors: [colors.workouts],
        semanticsLabel: l10n.progressSetsChartLabel,
        semanticsValue: l10n.progressSetsChartValue(
          _number(total),
          _number(most),
        ),
      ),
    );
  }

  /// Today's adaptive estimate over the last seven days' line, or the
  /// formula's before there is one.
  Widget expenditure() {
    final figures = state.expenditure;
    final today = figures?.today ?? 0;
    return _sparkline(
      title: l10n.expenditureTitle,
      subtitle: l10n.progressLast7Days,
      points: figures?.week ?? const [],
      unit: 'kcal',
      color: colors.expenditure,
      decimals: 0,
      value: today > 0 ? _number(today) : AppFormat.placeholder,
      onTap: () => router?.goNamed(ExpenditureMetric.expenditure.name),
    );
  }

  /// The week's mean intake over its logged days against today's estimate:
  /// a day with nothing logged is left out, not counted as eating nothing.
  Widget energyBalance() {
    final intake = [for (final day in state.macrosWeek) day.calories];
    final figures = state.expenditure;
    final average = loggedAverage(intake);
    final week = figures?.week ?? const <ProgressPoint>[];
    String kcal(Iterable<double> values) => values.isEmpty
        ? AppFormat.placeholder
        : AppFormat.kcal(
            (values.reduce((a, b) => a + b) / values.length).round(),
            locale: locale,
          );
    return ProgressCard(
      title: l10n.energyBalanceTitle,
      subtitle: average == null
          ? l10n.progressLast7Days
          : l10n.energyBalanceLoggedDays(average.days),
      value: average == null || figures == null
          ? AppFormat.placeholder
          : ExpenditureText.balance(
              l10n,
              expenditureKcal: figures.today,
              intakeKcal: average.meanKcal,
              locale: locale,
            ),
      onTap: () => router?.goNamed(ExpenditureMetric.energyBalance.name),
      chart: StackedBars(
        stacks: [
          for (final kcal in intake) [kcal],
        ],
        colors: [colors.calories],
        line: [for (final point in week) point.value],
        lineColor: colors.expenditure,
        semanticsLabel: l10n.energyBalanceChartLabel,
        semanticsValue: l10n.energyBalanceChartValue(
          kcal(intake),
          kcal([for (final point in week) point.value]),
        ),
      ),
    );
  }

  Widget weightTrend() => _sparkline(
    title: l10n.weightTrendTitle,
    subtitle: state.trendWeights.isEmpty
        ? l10n.progressNoEntries
        : l10n.progressLast7Days,
    points: state.trendWeights,
    unit: state.unit.symbol,
    color: colors.scaleWeight,
    onTap: () => router?.goNamed(WeightMetric.weightTrend.name),
  );

  Widget goalProgress() {
    final progress = state.goalProgress;
    final measured = progress.state == GoalProgressState.measured;
    return ProgressCard(
      title: l10n.progressGoalProgress,
      subtitle: switch (progress.state) {
        GoalProgressState.noGoal => l10n.progressNoGoalSet,
        GoalProgressState.noEntries => l10n.progressNoEntries,
        GoalProgressState.measured => l10n.progressTowardTarget,
      },
      value: measured ? _number(progress.percent) : AppFormat.placeholder,
      unit: '%',
      onTap: () => router?.goNamed(GoalProgressPage.name),
      chart: ProgressBarChart(
        current: progress.percent,
        maximum: 100,
        color: accent,
      ),
    );
  }

  Widget _habit(
    String title,
    List<bool> days,
    int thisWeek, {
    VoidCallback? onTap,
  }) => ProgressCard(
    title: title,
    subtitle: l10n.progressLast30Days,
    value: _number(thisWeek),
    unit: l10n.progressThisWeek,
    onTap: onTap,
    chart: HabitGridChart(
      days: days,
      color: colors.habits,
      semanticsValue: l10n.progressGridChartValue(
        _number(days.where((done) => done).length),
      ),
    ),
  );

  Widget weighInHabit() => _habit(
    l10n.progressWeighIn,
    state.weighInGrid,
    state.weighInsThisWeek,
    onTap: () => router?.goNamed(WeighInConsistencyPage.name),
  );

  /// Days with food logged (Swift `HabitsView`'s Food Logging card): this
  /// week's count out of seven.
  Widget foodLoggingHabit() => ProgressCard(
    title: l10n.progressFoodLogging,
    subtitle: l10n.progressLast30Days,
    value: l10n.progressOutOfSeven(_number(state.foodLoggedThisWeek)),
    unit: l10n.progressThisWeek,
    onTap: () => router?.goNamed(FoodLoggingConsistencyPage.name),
    chart: HabitGridChart(
      days: state.foodLoggingGrid,
      color: colors.habits,
      semanticsValue: l10n.progressGridChartValue(
        _number(state.foodLoggingGrid.where((done) => done).length),
      ),
    ),
  );

  Widget workoutHabit() => _habit(
    l10n.progressWorkouts,
    state.workoutGrid,
    state.workoutsThisWeek,
    onTap: () => router?.goNamed(WorkoutConsistencyPage.name),
  );

  Widget macros() {
    final week = state.macrosWeek;
    final logged = week.any(_isLogged);
    double average(double Function(Macros) of) =>
        week.fold<double>(0, (sum, day) => sum + of(day)) / week.length;
    String grams(double Function(Macros) of) =>
        AppFormat.grams(average(of), locale: locale);
    return ProgressCard(
      title: l10n.progressMacros,
      subtitle: logged ? l10n.progressLast7Days : l10n.progressNoData,
      value: logged
          ? _number(average((day) => day.calories))
          : AppFormat.placeholder,
      unit: 'kcal',
      onTap: () => _nutrition(NutritionMetric.macros),
      chart: StackedBars(
        stacks: [
          for (final day in week)
            [day.proteinGrams, day.carbGrams, day.fatGrams],
        ],
        colors: [colors.protein, colors.carbs, colors.fat],
        semanticsLabel: l10n.progressMacrosChartLabel(week.length),
        semanticsValue: logged
            ? l10n.progressMacrosChartValue(
                grams((day) => day.proteinGrams),
                grams((day) => day.carbGrams),
                grams((day) => day.fatGrams),
              )
            : null,
      ),
    );
  }

  Widget protein() {
    final logged = state.macrosWeek.any(_isLogged);
    final eaten = state.macrosWeek.last.proteinGrams;
    final target = state.proteinTarget;
    String grams(double value) => AppFormat.grams(value, locale: locale);
    return ProgressCard(
      title: l10n.progressProtein,
      subtitle: logged ? l10n.progressToday : l10n.progressNoData,
      value: logged ? _number(eaten, 1) : AppFormat.placeholder,
      unit: 'g',
      onTap: () => _nutrition(NutritionMetric.protein),
      chart: ProgressBarChart(
        current: eaten,
        maximum: proteinCeiling(eaten: eaten, target: target),
        target: target,
        color: colors.protein,
        semanticsValue: target == null || target <= 0
            ? grams(eaten)
            : l10n.progressOfTarget(grams(eaten), grams(target)),
      ),
    );
  }

  Widget scaleWeight() => _sparkline(
    title: l10n.scaleWeightTitle,
    subtitle: state.scaleWeights.isEmpty
        ? l10n.progressNoEntries
        : l10n.progressLast7Entries,
    points: state.scaleWeights,
    unit: state.unit.symbol,
    color: colors.scaleWeight,
    onTap: () => router?.goNamed(WeightMetric.scaleWeight.name),
  );

  Widget bodyFat() => _sparkline(
    title: l10n.progressVisualBodyFat,
    subtitle: state.bodyFat.isEmpty
        ? l10n.progressNoEntries
        : l10n.progressLast7Entries,
    points: state.bodyFat,
    unit: '%',
    color: colors.bodyFat,
    onTap: () => router?.goNamed(
      BodyMetricDetailPage.name,
      pathParameters: {
        BodyMetricDetailPage.metricParameter: BodyMetricDetailPage.bodyFatId,
      },
    ),
  );

  Widget steps() => _sparkline(
    title: l10n.progressSteps,
    subtitle: state.stepsWeek.isEmpty
        ? l10n.progressNoData
        : l10n.progressLast7Days,
    points: state.stepsWeek,
    unit: l10n.progressStepsUnit,
    color: colors.steps,
    decimals: 0,
    onTap: () => router?.goNamed(StepsPage.name),
  );

  static bool _isLogged(Macros day) =>
      day.calories > 0 ||
      day.proteinGrams > 0 ||
      day.carbGrams > 0 ||
      day.fatGrams > 0;

  void _nutrition(NutritionMetric metric) => router?.goNamed(
    NutritionMetricPage.name,
    pathParameters: {NutritionMetricPage.metricParameter: metric.name},
  );

  // MARK: Body Metrics

  /// A circumference's last seven readings, in the profile's length unit.
  Widget measurement(BodyMeasurementKind kind) {
    final readings = lastReadings(state.measurementReadings(kind));
    return _sparkline(
      title: bodyMeasurementName(l10n, kind),
      subtitle: readings.isEmpty
          ? l10n.progressNoEntries
          : l10n.progressLast7Entries,
      points: [for (final r in readings) (date: r.date, value: r.value)],
      unit: state.lengthSymbol,
      color: colors.measurements,
      onTap: () => _bodyDetail(kind.name),
    );
  }

  /// A ratio's last seven readings, to two decimal places and no unit.
  Widget ratio(BodyRatioKind kind) {
    final readings = lastReadings(state.ratioReadings(kind));
    return ProgressCard(
      title: bodyRatioName(l10n, kind),
      subtitle: readings.isEmpty
          ? l10n.progressNoEntries
          : l10n.progressLastEntries(readings.length),
      value: readings.isEmpty
          ? AppFormat.placeholder
          : ratioText(readings.last.value, locale),
      onTap: () => _bodyDetail(kind.name),
      chart: Sparkline(
        points: [for (final r in readings) (date: r.date, value: r.value)],
        color: colors.measurements,
      ),
    );
  }

  void _bodyDetail(String id) => router?.goNamed(
    BodyMetricDetailPage.name,
    pathParameters: {BodyMetricDetailPage.metricParameter: id},
  );

  // MARK: Nutrition

  /// Calories or a macro today against the plan's target (Swift
  /// `NutritionAnalyticsView.macroCard`).
  Widget macroToday(NutritionMetric metric) {
    final eaten = state.todayTotals;
    final target = state.todayTarget;
    final current = eaten == null ? 0.0 : metric.valueOf(eaten, const {});
    final goal = target == null ? null : metric.valueOf(target, const {});
    final decimals = metric == NutritionMetric.calories ? 0 : 1;
    return ProgressCard(
      title: nutritionMetricName(l10n, metric),
      subtitle: eaten == null ? l10n.progressNoData : l10n.progressToday,
      value: eaten == null ? AppFormat.placeholder : _number(current, decimals),
      unit: metric.unit,
      onTap: () => _nutrition(metric),
      chart: ProgressBarChart(
        current: current,
        maximum: macroChartMax(current, goal, macroFallback(metric)),
        target: goal,
        color: nutritionMetricColor(colors, metric),
      ),
    );
  }

  /// A nutrient today, with no target (Swift `breakdownCard`).
  Widget breakdown(NutritionMetric metric) {
    final value = state.todayBreakdown[metric.line];
    final figure = breakdownFigure(value);
    return ProgressCard(
      title: nutritionMetricName(l10n, metric),
      subtitle: l10n.progressToday,
      value: figure == null
          ? AppFormat.placeholder
          : _number(figure.value, figure.decimals),
      unit: metric.unit,
      onTap: () => _nutrition(metric),
      chart: ProgressBarChart(
        current: value ?? 0,
        maximum: breakdownChartMax(value),
        color: nutritionMetricColor(colors, metric),
      ),
    );
  }
}

/// A heading, with the method's info button and See All when given, and
/// its grid of cards (Swift's `SectionHeaderView` over an
/// `AnalyticsCardGrid`).
class ProgressCardSection extends StatelessWidget {
  const new({
    required this.header,
    required this.cards,
    this.info,
    this.onSeeAll,
    super.key,
  });

  /// The section's name.
  final String header;

  /// Its cards.
  final List<Widget> cards;

  /// The method behind its figures.
  final MethodInfo? info;

  /// Opens the section's own screen.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s,
      children: [
        AnalyticsSectionHeader(title: header, info: info, onSeeAll: onSeeAll),
        ProgressCardGrid(children: cards),
      ],
    ),
  );
}

/// A screen of card sections behind the Progress tab (Swift's
/// `List` of `AnalyticsCardGrid` sections), for Insights, Habits,
/// Nutrition and Body Metrics: a spinner, the failure message, or the
/// sections [build] makes from the state.
class ProgressSectionsView extends StatelessWidget {
  const new({required this.title, required this.sections, super.key});

  /// The screen's title.
  final String title;

  /// The sections, from the state.
  final List<Widget> Function(BuildContext context, ProgressState state)
  sections;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProgressBloc>().state;
    return AppScaffold(
      appBar: AppBar(title: Text(title)),
      body: switch (state.status) {
        ProgressStatus.loading => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        ProgressStatus.failure => ProgressMessage(
          title: title,
          message: context.l10n.progressLoadFailure,
        ),
        ProgressStatus.loaded => SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppContentWidth.dashboard,
              ),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.l),
                children: sections(context, state),
              ),
            ),
          ),
        ),
      },
    );
  }
}
