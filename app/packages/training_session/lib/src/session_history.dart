/// "Last time", read out of the user's sessions: the lookups the Swift
/// session manager makes over its synced collection, the one resolution of
/// `previousWorkoutReference` (`CoreInteractor+PreviousWorkoutReference`),
/// smart progression's suggestions (`CoreInteractor+Progression`) and the
/// planned session (`CoreInteractor.plannedSession`).
library;

import 'package:compound_models/compound_models.dart' as m;
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/src/library_exercise.dart';
import 'package:training_session/src/mapping.dart';
import 'package:training_session/src/model_copies.dart';
import 'package:training_session/src/session_builder.dart';
import 'package:training_session/src/session_load.dart';
import 'package:training_session/src/weight_stepper.dart';

/// The equipment and unit one template exercise starts a session on
/// (`SessionLoad`).
typedef SessionLoad = ({
  List<m.EquipmentRef>? resistanceEquipment,
  m.ExerciseWeightUnit? weightUnit,
});

/// The user's sessions, as the Swift app holds them synced.
class const SessionHistory(final List<m.WorkoutSessionModel> sessions) {
  /// The latest session of [templateId], finished or not, by start
  /// (`getLastWorkoutSessionForTemplate`).
  m.WorkoutSessionModel? lastForTemplate(String templateId) {
    m.WorkoutSessionModel? latest;
    for (final session in sessions) {
      if (session.workoutTemplateId != templateId) continue;
      if (latest == null || session.dateCreated.isAfter(latest.dateCreated)) {
        latest = session;
      }
    }
    return latest;
  }

  /// The latest finished sessions matching [test], most recently ended
  /// first, in [mesocycleId] when given.
  List<m.WorkoutSessionModel> _completed(
    bool Function(m.WorkoutSessionModel) test, {
    required String? mesocycleId,
    required int limit,
  }) =>
      (sessions
              .where(
                (session) =>
                    session.endedAt != null &&
                    test(session) &&
                    (mesocycleId == null || session.mesocycleId == mesocycleId),
              )
              .toList()
            ..sort((a, b) => b.endedAt!.compareTo(a.endedAt!)))
          .take(limit < 0 ? 0 : limit)
          .toList();

  /// The last finished sessions of one workout template
  /// (`getLastCompletedSessionsForTemplate`).
  List<m.WorkoutSessionModel> completedForTemplate(
    String templateId, {
    String? mesocycleId,
    int limit = 3,
  }) => _completed(
    (session) => session.workoutTemplateId == templateId,
    mesocycleId: mesocycleId,
    limit: limit,
  );

  /// The last finished sessions holding one exercise, whatever the workout
  /// (`getLastCompletedSessionsContainingExercise`).
  List<m.WorkoutSessionModel> completedContainingExercise(
    String exerciseTemplateId, {
    String? mesocycleId,
    int limit = 3,
  }) => _completed(
    (session) =>
        session.exercises.any((e) => e.templateId == exerciseTemplateId),
    mesocycleId: mesocycleId,
    limit: limit,
  );

  /// The sessions "last time" is read from for one exercise of one workout:
  /// this workout's own history unless [scope] is any exercise, falling back
  /// to wherever the exercise was last done when that holds nothing for it
  /// (`previousSessions(forExerciseTemplateId:…)`).
  List<m.WorkoutSessionModel> previousSessions({
    required String exerciseTemplateId,
    required String? workoutTemplateId,
    required String? mesocycleId,
    required m.PreviousWorkoutReferenceOption scope,
    int limit = 3,
  }) {
    if (scope != m.PreviousWorkoutReferenceOption.anyExercise &&
        workoutTemplateId != null) {
      final fromTemplate =
          completedForTemplate(
            workoutTemplateId,
            mesocycleId:
                scope == m.PreviousWorkoutReferenceOption.workoutsInMesocycle
                ? mesocycleId
                : null,
            limit: limit,
          ).where(
            (session) => session.exercises.any(
              (e) => e.templateId == exerciseTemplateId,
            ),
          );
      if (fromTemplate.isNotEmpty) return fromTemplate.toList();
    }
    return completedContainingExercise(exerciseTemplateId, limit: limit);
  }

  /// One context's suggestion, keyed by its history key; history resolved
  /// per exercise, ten deep (`suggestions(for:…)`).
  Map<String, r.ProgressionSuggestion> suggestions({
    required List<r.ProgressionContext> contexts,
    required String? workoutTemplateId,
    required String? mesocycleId,
    required m.WorkoutSettings settings,
  }) {
    final rules = rulesSettings(settings);
    return {
      for (final context in contexts)
        ...r.ProgressionPlanner.suggestions(
          contexts: [context],
          history: previousSessions(
            exerciseTemplateId: context.templateId,
            workoutTemplateId: workoutTemplateId,
            mesocycleId: mesocycleId,
            scope: settings.previousWorkoutReference,
            limit: 10,
          ).map(rulesSession).toList(),
          adjustmentMode: settings.smartProgressionAdjustmentMode.rules,
          amrap: r.AmrapProgression.fromSettings(rules),
        ),
    };
  }

  /// What the user last did for each of [exercises] of [session], by history
  /// key: the nth appearance matched to the nth appearance last time, on the
  /// same kind of load and outside a deload week; the last time it was done,
  /// else the last time it was planned (`loadPrevious(for:)`). An exercise
  /// with no such session maps to `null`.
  Map<String, m.WorkoutExerciseModel?> previousExercises({
    required m.WorkoutSessionModel session,
    required List<m.WorkoutExerciseModel> exercises,
    required m.PreviousWorkoutReferenceOption scope,
  }) {
    final resolved = <String, m.WorkoutExerciseModel?>{};
    for (final exercise in exercises) {
      final occurrence = session.occurrenceOf(exercise);
      final refs = exercise.activeVariation?.resistanceEquipment;
      final candidates = [
        for (final past in previousSessions(
          exerciseTemplateId: exercise.templateId,
          workoutTemplateId: session.workoutTemplateId,
          mesocycleId: session.mesocycleId,
          scope: scope,
          limit: 5,
        ))
          if (past.isDeload != true)
            if (past.exercise(exercise.templateId, occurrence)
                case final match?)
              if (sameLoad(match.activeVariation?.resistanceEquipment, refs))
                match,
      ];
      resolved[r.historyKeyFor(exercise.templateId, occurrence)] =
          candidates
              .where(
                (match) => rulesExercise(match).loggedWorkingSets.isNotEmpty,
              )
              .firstOrNull ??
          candidates.firstOrNull;
    }
    return resolved;
  }
}

/// The equipment each template exercise starts on and its unit, as the
/// session will choose them (`sessionLoads(of:previous:gym:unitPreferences:)`).
List<SessionLoad> sessionLoads(
  m.WorkoutTemplateModel template, {
  required m.WorkoutSessionModel? previous,
  required m.GymProfileModel? gym,
  required Map<String, UnitPreference> unitPreferences,
}) => [
  for (final (index, templateExercise) in template.exercises.indexed)
    () {
      final exercise = templateExercise.exercise;
      final occurrence = template.exercises
          .take(index)
          .where((e) => e.exercise.id == exercise.id)
          .length;
      final chosen = SessionLoadChoice.variationId(
        variations: exercise.equipmentVariations,
        previous: previous?.exercise(exercise.id, occurrence),
        previousGymId: previous?.gymProfileId,
        gym: gym,
      );
      final refs = exercise.equipmentVariations
          .where((variation) => variation.id == chosen)
          .firstOrNull
          ?.resistanceEquipment;
      return (
        resistanceEquipment: refs,
        weightUnit: SessionLoadChoice.weightUnit(
          preference: unitPreferences[exercise.id],
          refs: refs,
          gym: gym,
        ),
      );
    }(),
];

/// One template exercise as the progression engine takes it
/// (`ExerciseContext(templateExercise:…)`), rounded on [gym].
r.ProgressionContext templateContext(
  m.WorkoutTemplateExercise templateExercise, {
  required m.GymProfileModel? gym,
  required SessionLoad? load,
  required int occurrence,
}) {
  final exercise = templateExercise.exercise;
  final refs = load?.resistanceEquipment;
  return r.ProgressionContext(
    templateId: exercise.id,
    trackingMode: exercise.trackingMode.rules,
    setTargets: templateExercise.setTargets.map(rulesTarget).toList(),
    rounding: progressionRounding(
      weightRoundingRule(
        exercise: exercise,
        gym: gym,
        preferredUnit: load?.weightUnit,
        resistanceEquipment: refs,
      ),
    ),
    exerciseType: exercise.type?.rules,
    resistanceEquipment: rulesRefs(
      refs ?? exercise.equipmentVariations.firstOrNull?.resistanceEquipment,
    ),
    occurrence: occurrence,
  );
}

/// One session exercise as the progression engine takes it
/// (`ExerciseContext(sessionExercise:…)`); [library] is its library entry.
r.ProgressionContext sessionContext(
  m.WorkoutExerciseModel exercise, {
  required m.ExerciseModel? library,
  required m.GymProfileModel? gym,
  required m.ExerciseWeightUnit? preferredUnit,
  int occurrence = 0,
}) {
  final refs = exercise.activeVariation?.resistanceEquipment;
  return r.ProgressionContext(
    templateId: exercise.templateId,
    trackingMode: exercise.trackingMode.rules,
    setTargets: exercise.setTargets.map(rulesTarget).toList(),
    rounding: progressionRounding(
      weightRoundingRule(
        exercise: library,
        gym: gym,
        preferredUnit: preferredUnit,
        resistanceEquipment: refs,
      ),
    ),
    exerciseType: library?.type?.rules,
    resistanceEquipment: rulesRefs(
      refs ?? library?.equipmentVariations.firstOrNull?.resistanceEquipment,
    ),
    occurrence: occurrence,
  );
}

/// How a session started from [week] fills its working sets, as Initial Log
/// Fill asks (`sessionPrefill(for:…)`). Smart progression rounds on
/// [workoutGym], the workout's gym or the favourite, as Swift does.
r.SessionPrefill sessionPrefill(
  m.WorkoutTemplateModel week, {
  required String? mesocycleId,
  required List<SessionLoad> loads,
  required m.WorkoutSettings settings,
  required SessionHistory history,
  required m.GymProfileModel? workoutGym,
}) => switch (settings.smartProgressionInitialLogFill) {
  m.InitialLogFillOption.previousValues => const r.PrefillPreviousValues(),
  m.InitialLogFillOption.empty => const r.PrefillEmpty(),
  m.InitialLogFillOption.smartProgression => r.PrefillSuggestions(
    history.suggestions(
      contexts: [
        for (final (index, exercise) in week.exercises.indexed)
          templateContext(
            exercise,
            gym: workoutGym,
            load: index < loads.length ? loads[index] : null,
            occurrence: week.exercises
                .take(index)
                .where((e) => e.exercise.id == exercise.exercise.id)
                .length,
          ),
      ],
      workoutTemplateId: week.workoutId,
      mesocycleId: mesocycleId,
      settings: settings,
    ),
  ),
};

/// The session starting [template] would begin, prefilled
/// (`CoreInteractor.plannedSession`): each exercise as the library has it
/// now, last time from [history], on the template's gym (from [gyms]) or
/// else [workoutGym] (the workout's gym or the favourite).
m.WorkoutSessionModel plannedSession({
  required String authorId,
  required m.WorkoutTemplateModel template,
  required List<m.ExerciseModel> library,
  required SessionHistory history,
  required m.WorkoutSettings settings,
  required List<m.GymProfileModel> gyms,
  required m.GymProfileModel? workoutGym,
  required DateTime now,
  Map<String, UnitPreference> unitPreferences = const {},
  String? mesocycleId,
  int? microcycleIndex,
  IdGenerator newId = newUuid,
}) {
  final current = withLibraryExercises(template, library);
  final previous = history.lastForTemplate(current.workoutId);
  final gym =
      gyms.where((gym) => gym.id == current.gymProfileId).firstOrNull ??
      workoutGym;
  return sessionFromTemplate(
    authorId: authorId,
    template: current,
    now: now,
    newId: newId,
    mesocycleId: mesocycleId,
    microcycleIndex: microcycleIndex,
    previousSession: previous,
    gym: gym,
    unitPreferences: unitPreferences,
    prefill: sessionPrefill(
      weekOf(current, microcycleIndex),
      mesocycleId: mesocycleId,
      loads: sessionLoads(
        current,
        previous: previous,
        gym: gym,
        unitPreferences: unitPreferences,
      ),
      settings: settings,
      history: history,
      workoutGym: workoutGym,
    ),
    plansSets: rulesSettings(settings).plansSets,
  );
}

/// [session] as a deload week's (`WorkoutSessionModel.applyDeload`): about
/// half its working sets, each weight 10 % lighter on what its equipment in
/// [gym] makes (`deloadRounding`), and marked a deload.
m.WorkoutSessionModel deloadedSession(
  m.WorkoutSessionModel session, {
  required List<m.ExerciseModel> library,
  required m.GymProfileModel? gym,
  required DateTime now,
  Map<String, UnitPreference> unitPreferences = const {},
}) {
  final byId = {
    for (final exercise in session.exercises) exercise.id: exercise,
  };
  final rules = r.MesocycleDeload.apply(rulesSession(session), (exercise) {
    final stored = byId[exercise.id]!;
    return weightRoundingRule(
      exercise: library
          .where((candidate) => candidate.id == stored.templateId)
          .firstOrNull,
      gym: gym,
      preferredUnit:
          stored.weightUnit ?? unitPreferences[stored.templateId]?.weightUnit,
      resistanceEquipment: stored.activeVariation?.resistanceEquipment,
    ).round;
  });
  return session.copyWith(
    isDeload: true,
    exercises: modelExercises(
      rules.exercises,
      exercises: session.exercises,
      now: now,
    ),
  );
}
