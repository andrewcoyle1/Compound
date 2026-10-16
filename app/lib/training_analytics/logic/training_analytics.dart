/// The training analytics' arithmetic (Swift `ExerciseOneRMAggregator`,
/// `MuscleGroupSetsAggregator`, `MuscleVolume`, `VolumeRecommendation` and
/// the presenters that read them): the logged models turned into
/// `compound_maths`' types, and the figures each screen shows. Pure, so the
/// blocs and widgets only read it. The words live in the ARB strings.
library;

import 'package:compound/nutrition/logic/meal_day.dart' show dayKeyOf;
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:compound_models/compound_models.dart';

/// [session] as the maths reads it: dated by its end (else its start), a
/// set's weight being its load as shown (a machine base kept out of it stays
/// out of its 1RM), each exercise with its planned set count.
maths.WorkoutSession mathsSession(WorkoutSessionModel session) {
  final at = session.endedAt ?? session.dateCreated;
  return maths.WorkoutSession(
    day: dayKeyOf(at.toLocal()),
    at: at,
    isDeload: session.isDeload ?? false,
    exercises: [
      for (final exercise in session.exercises)
        maths.WorkoutExercise(
          templateId: exercise.templateId,
          name: exercise.name,
          plannedSets: exercise.setTargets.length,
          sets: [
            for (final set in exercise.sets)
              maths.WorkoutSet(
                id: set.id,
                reps: set.reps,
                weightKg: set.loadKg,
                rpe: set.rpe,
                side: switch (set.side) {
                  null => null,
                  final side => maths.SetSide.values.byName(side.name),
                },
                kind: maths.SetKind.values.byName(set.kind.name),
                parentSetId: set.parentSetId,
                isWarmup: set.isWarmup,
                completed: set.completedAt != null,
              ),
          ],
        ),
    ],
  );
}

/// The maths' muscle for [muscle].
maths.Muscle mathsMuscle(Muscles muscle) =>
    maths.Muscle.values.byName(muscle.name);

/// The muscles each of [exercises] trains, by id, as the maths reads them.
Map<String, Map<maths.Muscle, maths.MuscleTarget>> muscleTargets(
  Iterable<ExerciseModel> exercises,
) => {
  for (final exercise in exercises)
    exercise.id: {
      for (final MapEntry(:key, :value) in exercise.muscleGroups.entries)
        mathsMuscle(key): value == MuscleTargetType.secondary
            ? maths.MuscleTarget.secondary
            : maths.MuscleTarget.primary,
    },
};

/// The user's exercises and then the system ones, each id once (the user's
/// copy first), by name (`ExerciseAnalyticsPresenter.loadData`).
List<ExerciseModel> exerciseLibrary(
  List<ExerciseModel> user,
  List<ExerciseModel> system,
) {
  final seen = <String>{};
  return [
    for (final exercise in [...user, ...system])
      if (seen.add(exercise.id)) exercise,
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// Whether [muscle] is in the upper body (`Muscles.bodyRegion`).
bool isUpperBody(Muscles muscle) => switch (muscle) {
  Muscles.quads ||
  Muscles.hamstrings ||
  Muscles.glutes ||
  Muscles.calves ||
  Muscles.abductors ||
  Muscles.adductors ||
  Muscles.tibialis => false,
  _ => true,
};

/// Local midnight on [dayKey].
DateTime dayOf(String dayKey) {
  final date = DateTime.parse(dayKey);
  return DateTime(date.year, date.month, date.day);
}

/// One exercise's 1RM card: its last seven workouts' best estimates, oldest
/// first, and the best of them, in kilograms; no points when never done.
typedef ExerciseCard = ({
  String id,
  String name,
  List<({DateTime date, double kg})> points,
  double bestKg,
});

/// A card for every exercise in [library], in its order
/// (`ExerciseAnalyticsPresenter.exerciseCards`).
List<ExerciseCard> exerciseCards(
  List<maths.WorkoutSession> sessions,
  List<ExerciseModel> library,
) {
  final estimates = maths.exerciseOneRepMax(sessions);
  return [
    for (final exercise in library)
      (
        id: exercise.id,
        name: exercise.name,
        points: [
          for (final point
              in estimates[exercise.id]?.last7Workouts.reversed ??
                  const <maths.OneRepMaxPoint>[])
            (date: point.at, kg: point.value),
        ],
        bestKg: estimates[exercise.id]?.latest1RM ?? 0,
      ),
  ];
}

/// The two strongest of [cards] for the Progress tab: the best estimates
/// first (`loadExerciseCardsData`).
List<ExerciseCard> topExerciseCards(List<ExerciseCard> cards) =>
    ([...cards]..sort((a, b) => b.bestKg.compareTo(a.bestKg))).take(2).toList();

/// [templateId]'s best estimated 1RM on each day it was done, in
/// kilograms, oldest first (`ExerciseDetailPresenter.computeOneRMByDay`).
List<({DateTime date, double kg})> oneRepMaxByDay(
  List<maths.WorkoutSession> sessions,
  String templateId,
) {
  final best = <String, double>{};
  for (final session in sessions) {
    for (final exercise in session.exercises) {
      if (exercise.templateId != templateId) continue;
      for (final set in exercise.sets) {
        if (set.isWarmup || !set.completed || set.isSubSet) continue;
        final estimate = maths.setEstimatedOneRepMax(set);
        if (estimate == null || estimate <= (best[session.day] ?? 0)) continue;
        best[session.day] = estimate;
      }
    }
  }
  return [
    for (final day in best.keys.toList()..sort())
      (date: dayOf(day), kg: best[day]!),
  ];
}

/// Each of the last seven days' sets for one muscle, oldest first, today
/// last ([today] a day key), from `dailyMuscleSets`.
List<double> lastSevenDays(Map<String, double>? days, String today) => [
  for (var i = 6; i >= 0; i--) days?[maths.addDays(today, -i)] ?? 0,
];

/// The muscles the Progress tab shows: the two with the most sets in the
/// last seven days, or upper back and rear delts when none was trained
/// (`loadMuscleGroupsData`).
List<Muscles> topMuscles(Map<Muscles, List<double>> lastSeven) {
  double week(Muscles m) => lastSeven[m]?.fold<double>(0, (a, b) => a + b) ?? 0;
  final trained = Muscles.values.where((m) => week(m) > 0).toList()
    ..sort((a, b) => week(b).compareTo(week(a)));
  return trained.isEmpty
      ? const [Muscles.upperBack, Muscles.rearDelts]
      : trained.take(2).toList();
}

/// Whole years from [birth] to [now].
int? ageOn(DateTime? birth, DateTime now) {
  if (birth == null) return null;
  final hadBirthday =
      now.month > birth.month ||
      (now.month == birth.month && now.day >= birth.day);
  return now.year - birth.year - (hadBirthday ? 0 : 1);
}
