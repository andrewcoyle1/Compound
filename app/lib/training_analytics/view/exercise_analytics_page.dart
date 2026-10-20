import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/progress/view/card_charts.dart';
import 'package:compound/progress/view/progress_card.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/training_analytics/bloc/training_analytics_bloc.dart';
import 'package:compound/training_analytics/logic/training_analytics.dart';
import 'package:compound/training_analytics/view/training_analytics_widgets.dart';
import 'package:compound/training_analytics/view/training_metric_pages.dart';
import 'package:go_router/go_router.dart';

/// Every exercise's estimated one-rep max over its last seven workouts
/// (Swift `ExerciseAnalyticsView`). Pushed from the Progress tab's
/// Exercises section.
class ExerciseAnalyticsPage extends StatelessWidget {
  const new({super.key});

  /// The path under the Progress tab.
  static const path = 'exercises';

  /// The route name.
  static const name = 'exerciseAnalytics';

  @override
  Widget build(BuildContext context) => const TrainingAnalyticsProvider(
    screen: TrainingAnalyticsScreen.exercises,
    child: ExerciseAnalyticsView(),
  );
}

class ExerciseAnalyticsView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.progressExercises)),
      body: TrainingAnalyticsBody(
        title: l10n.progressExercises,
        loaded: (state) => ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            AnalyticsSectionHeader(
              title: l10n.progressExercises,
              info: MethodInfo.estimatedOneRepMax(l10n),
            ),
            const SizedBox(height: AppSpacing.s),
            ProgressCardGrid(
              children: [
                for (final card in state.exerciseCardList)
                  ExerciseOneRepMaxCard(
                    card: card,
                    usesPounds: state.usesPoundsFor(card.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One exercise's 1RM tile: its last seven workouts' estimates and the
/// best, in the unit shown; it opens the exercise's screen.
class ExerciseOneRepMaxCard extends StatelessWidget {
  const new({
    required this.card,
    required this.usesPounds,
    this.onTap,
    super.key,
  });

  /// The figures, in kilograms.
  final ExerciseCard card;

  /// Whether to show pounds.
  final bool usesPounds;

  /// Opens the exercise's screen; by default its route under Progress.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final unit = usesPounds ? AppWeightUnit.pounds : AppWeightUnit.kilograms;
    double inUnit(double kg) =>
        usesPounds ? kg * AppFormat.poundsPerKilogram : kg;
    String number(double v) =>
        AppFormat.number(v, maxFractionDigits: 1, locale: locale);
    final points = [
      for (final p in card.points) (date: p.date, value: inUnit(p.kg)),
    ];
    return ProgressCard(
      title: card.name,
      subtitle: l10n.progressLast7Workouts,
      value: card.bestKg > 0
          ? number(inUnit(card.bestKg))
          : AppFormat.placeholder,
      unit: unit.symbol,
      onTap:
          onTap ??
          () => context.goNamed(
            ExerciseOneRepMaxPage.name,
            pathParameters: {ExerciseOneRepMaxPage.idParameter: card.id},
          ),
      chart: Sparkline(
        points: points,
        color: context.appColors.exercises,
        semanticsValue: points.isEmpty
            ? null
            : l10n.progressTrendChartValue(
                '${number(points.first.value)} ${unit.symbol}',
                '${number(points.last.value)} ${unit.symbol}',
              ),
      ),
    );
  }
}
