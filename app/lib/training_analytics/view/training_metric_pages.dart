import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/training_analytics/bloc/training_analytics_bloc.dart';
import 'package:compound/training_analytics/view/training_analytics_widgets.dart';
import 'package:compound/training_analytics/view/training_metric_view.dart';
import 'package:compound/training_analytics/view/volume_recommendation_section.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound_models/compound_models.dart' show Muscles;

/// One exercise's best estimated one-rep max each day it was done (Swift
/// `ExerciseDetailView`), in the profile's weight unit.
class ExerciseOneRepMaxPage extends StatelessWidget {
  const new({required this.exerciseId, this.allData = false, super.key});

  /// The path under Exercises.
  static const path = ':$idParameter';

  /// The route name, and its All Recorded Data's.
  static const name = 'exerciseOneRepMax';
  static const dataName = 'exerciseOneRepMaxData';

  /// The exercise id's path parameter.
  static const idParameter = 'exerciseId';

  /// The exercise.
  final String exerciseId;

  /// Whether to show every entry instead of the chart.
  final bool allData;

  @override
  Widget build(BuildContext context) => TrainingAnalyticsProvider(
    screen: TrainingAnalyticsScreen.exerciseDetail,
    parameters: {'exercise_template_id': exerciseId},
    child: TrainingMetricView(
      allData: allData,
      allDataRoute: dataName,
      pathParameters: {idParameter: exerciseId},
      metric: (context, state) {
        final l10n = context.l10n;
        final name = state.exerciseName(exerciseId);
        return TrainingMetric(
          title: name,
          unit: state.usesPounds
              ? AppWeightUnit.pounds.symbol
              : AppWeightUnit.kilograms.symbol,
          points: state.oneRepMaxPoints(exerciseId),
          seriesLabel: l10n.oneRepMaxSeries,
          color: context.appColors.exercises,
          emptyMessage: l10n.oneRepMaxEmpty(name),
          info: MethodInfo.estimatedOneRepMax(l10n),
        );
      },
    ),
  );
}

/// One muscle's hard sets each day it was trained, and the suggestion for
/// its next weeks of sets (Swift `MuscleGroupDetailView`).
class MuscleGroupDetailPage extends StatelessWidget {
  const new({required this.muscle, this.allData = false, super.key});

  /// The path under Muscle Groups.
  static const path = ':$muscleParameter';

  /// The route name, and its All Recorded Data's.
  static const name = 'muscleGroupDetail';
  static const dataName = 'muscleGroupDetailData';

  /// The muscle's path parameter: its stored raw value.
  static const muscleParameter = 'muscle';

  /// The muscle.
  final Muscles muscle;

  /// Whether to show every entry instead of the chart.
  final bool allData;

  @override
  Widget build(BuildContext context) => TrainingAnalyticsProvider(
    screen: TrainingAnalyticsScreen.muscleGroupDetail,
    parameters: {'muscle': muscle.value},
    child: TrainingMetricView(
      allData: allData,
      allDataRoute: dataName,
      pathParameters: {muscleParameter: muscle.value},
      metric: (context, state) {
        final l10n = context.l10n;
        final locale = Localizations.localeOf(context).toLanguageTag();
        final name = l10n.muscleName(muscle);
        final points = state.muscleSetPoints(muscle);
        return TrainingMetric(
          title: name,
          unit: l10n.progressSetsUnit,
          points: points,
          isBar: true,
          seriesLabel: l10n.statSets,
          color: context.appColors.muscleGroups,
          emptyMessage: l10n.muscleSetsEmpty(name),
          info: MethodInfo.weeklyHardSets(l10n),
          summary: VolumeRecommendationSection(
            suggestion: state.recommendation(muscle),
          ),
          entryText: (index) =>
              setsText(l10n, points[points.length - 1 - index].value, locale),
        );
      },
    ),
  );
}

/// Every finished workout's working sets (Swift `WorkoutView`).
class WorkoutMetricPage extends StatelessWidget {
  const new({this.allData = false, super.key});

  /// The path under the Progress tab.
  static const path = 'workouts';

  /// The route name, and its All Recorded Data's.
  static const name = 'workoutMetric';
  static const dataName = 'workoutMetricData';

  /// Whether to show every entry instead of the chart.
  final bool allData;

  @override
  Widget build(BuildContext context) => TrainingAnalyticsProvider(
    screen: TrainingAnalyticsScreen.workouts,
    child: TrainingMetricView(
      allData: allData,
      allDataRoute: dataName,
      metric: (context, state) =>
          workoutsMetric(context, state, color: context.appColors.workouts),
    ),
  );
}

/// The Workouts metric: each session's sets as a bar, newest entries
/// reading "12 sets · 5,040 kg" in the unit the session was lifted in.
TrainingMetric workoutsMetric(
  BuildContext context,
  TrainingAnalyticsState state, {
  required Color color,
}) {
  final l10n = context.l10n;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final workouts = state.workouts;
  final sessions = state.finished;
  return TrainingMetric(
    title: l10n.progressWorkouts,
    unit: '',
    points: [
      for (final w in workouts.reversed)
        (date: w.date, value: w.sets.toDouble()),
    ],
    isBar: true,
    seriesLabel: l10n.statSets,
    color: color,
    emptyMessage: l10n.workoutsEmpty,
    entryText: (index) {
      final sets = l10n.setCount(workouts[index].sets);
      final volume = WorkoutText.sessionVolume(sessions[index], locale: locale);
      return volume == null ? sets : '$sets · $volume';
    },
  );
}
