import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/expenditure/expenditure.dart';
import 'package:compound/expenditure_metric/expenditure_metric.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/progress/bloc/progress_bloc.dart';
import 'package:compound/progress/logic/progress_overview.dart';
import 'package:compound/progress/view/card_charts.dart';
import 'package:compound/progress/view/progress_card.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:compound_maths/compound_maths.dart' show Macros, loggedAverage;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// The Progress tab (Swift `AnalyticsView`), read only: the cards that are
/// built from synced data alone, in the Swift sections, honouring the
/// sections the user has hidden. The header carousel waits for a later
/// slice; Muscle Groups and Exercises need the exercise library (M5).
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
        checkInRepository: context.read<CheckInRepository>(),
        uid: state.user.uid,
        firstWeekday: firstDay == 0 ? DateTime.sunday : firstDay,
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
        actions: const [ProfileButton()],
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
    final cards = _Cards(context, state);
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
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              for (final section in ProgressSection.values)
                if (state.isVisible(section))
                  ...switch (section) {
                    ProgressSection.insightsAndAnalytics => [
                      _Section(
                        header: l10n.progressInsightsHeader,
                        cards: [
                          cards.workouts(),
                          cards.expenditure(),
                          cards.weightTrend(),
                          cards.goalProgress(),
                          cards.energyBalance(),
                        ],
                      ),
                    ],
                    ProgressSection.habits => [
                      _Section(
                        header: l10n.progressHabitsHeader,
                        cards: [cards.weighInHabit(), cards.workoutHabit()],
                      ),
                    ],
                    ProgressSection.nutrition => [
                      _Section(
                        header: l10n.progressNutritionHeader,
                        cards: [cards.macros(), cards.protein()],
                      ),
                    ],
                    ProgressSection.bodyMetrics => [
                      _Section(
                        header: l10n.progressBodyMetricsHeader,
                        cards: [cards.scaleWeight(), cards.bodyFat()],
                      ),
                    ],
                    // Need the exercise library and set aggregation (M5).
                    ProgressSection.muscleGroups ||
                    ProgressSection.exercises => const <Widget>[],
                  },
              // Not hideable in Swift either.
              _Section(
                header: l10n.progressGeneralHeader,
                cards: [cards.steps()],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A heading and its grid of cards.
class _Section extends StatelessWidget {
  const new({required this.header, required this.cards});

  final String header;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.l),
          child: Semantics(
            header: true,
            child: Text(
              header,
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        ProgressCardGrid(children: cards),
      ],
    ),
  );
}

/// Builds each card from the state (Swift `AnalyticsPresenter`'s text
/// properties). A missing figure reads as the placeholder, never 0.
class _Cards {
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
      chart: ProgressBarChart(
        current: progress.percent,
        maximum: 100,
        color: accent,
      ),
    );
  }

  Widget _habit(String title, List<bool> days, int thisWeek) => ProgressCard(
    title: title,
    subtitle: l10n.progressLast30Days,
    value: _number(thisWeek),
    unit: l10n.progressThisWeek,
    chart: HabitGridChart(
      days: days,
      color: colors.habits,
      semanticsValue: l10n.progressGridChartValue(
        _number(days.where((done) => done).length),
      ),
    ),
  );

  Widget weighInHabit() =>
      _habit(l10n.progressWeighIn, state.weighInGrid, state.weighInsThisWeek);

  Widget workoutHabit() =>
      _habit(l10n.progressWorkouts, state.workoutGrid, state.workoutsThisWeek);

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
  );

  static bool _isLogged(Macros day) =>
      day.calories > 0 ||
      day.proteinGrams > 0 ||
      day.carbGrams > 0 ||
      day.fatGrams > 0;
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
