/// How long the rest after a set is, and what a set needs before it can be
/// logged (`RestDurationRules.swift`, `SetValidation.swift`). Sources and
/// Compound's own choices: `MethodInfo.restIntervals`.
library;

import 'package:training_rules/src/models.dart';

/// What the rest rules need to know about the exercise
/// (`RestDurationRules.ExerciseContext`).
class const RestContext({
  /// The rest set on this exercise everywhere.
  final int? restOverrideSeconds,
  final ExerciseType? exerciseType,

  /// The plan's rest on this exercise in this workout.
  final int? planRestSeconds,
});

/// How long to rest after a set (`RestDurationRules`).
abstract final class RestDurationRules {
  /// Sets of this many reps or fewer on a multi-joint lift count as heavy.
  static const heavyRepCeiling = 6;

  /// The unscaled rest, narrowest setting first: the plan's, the exercise's,
  /// the user's for its type, the type's default, then the global default.
  /// A zero from the plan or the exercise reads as none.
  static int baseRestDuration(
    WorkoutSettings settings,
    RestContext context, {
    int? reps,
  }) {
    final plan = context.planRestSeconds;
    if (plan != null && plan > 0) return plan;
    final override = context.restOverrideSeconds;
    if (override != null && override > 0) return override;
    final type = context.exerciseType;
    if (type == null) return settings.defaultRestDurationSeconds;
    return settings.restDurationsByExerciseType[type] ??
        defaultSeconds(type, reps);
  }

  /// A type's rest until the user sets their own (ACSM 2009, Singer 2024):
  /// heavy multi-joint work 180 s, other multi-joint 120 s, isolation 90 s,
  /// core 60 s.
  static int defaultSeconds(ExerciseType type, int? reps) => switch (type) {
    ExerciseType.compoundUpper || ExerciseType.compoundLower =>
      reps != null && reps > 0 && reps <= heavyRepCeiling ? 180 : 120,
    ExerciseType.isolationUpper || ExerciseType.isolationLower => 90,
    ExerciseType.core => 60,
  };

  /// The rest after [set] within its exercise, or `null` for none. A rest set
  /// by hand wins unscaled; otherwise the base is scaled by where the set
  /// sits: after the last warm-up, between limbs, after the last set.
  static int? restAfterCompletingInExercise(
    WorkoutSet set,
    WorkoutExercise exercise,
    WorkoutSettings settings,
    RestContext context, {
    int? customRestSeconds,
  }) {
    if (customRestSeconds != null) return customRestSeconds;

    final parentReps = _byId(exercise, set.parentSetId)?.reps;
    final base = baseRestDuration(
      settings,
      context,
      reps: set.isWarmup ? null : parentReps ?? set.reps,
    );

    if (set.isWarmup) {
      if (!_isLastWarmup(set, exercise) || !settings.restAfterLastWarmUp) {
        return null;
      }
      return _scale(base, settings.warmUpRestScaling);
    }

    final next = _followingSubSet(set, exercise);
    if (next != null) return _intraSetRest(next, exercise, settings);
    final parent = _byId(exercise, set.parentSetId) ?? set;

    if (_hasFollowingSidePartner(parent, exercise)) {
      if (!settings.restBetweenSideSets) return null;
      return _scale(base, settings.sideSetRestScaling);
    }
    if (_isLastWorkingSet(parent, exercise)) {
      if (!settings.restBetweenExercises) return null;
      return _scale(base, settings.betweenExercisesRestScaling);
    }
    return base;
  }

  /// The rest after [set] knowing the whole workout: none after the last
  /// open set, and in a superset a walk to the partner, the base after the
  /// round and the between-exercises rest after the block. [workout] may hold
  /// [set] logged or not.
  static int? restAfterCompleting(
    WorkoutSet set,
    WorkoutExercise exercise,
    List<WorkoutExercise> workout,
    WorkoutSettings settings,
    RestContext context, {
    int? customRestSeconds,
  }) {
    bool isOpen(WorkoutSet candidate) =>
        candidate.completedAt == null && candidate.id != set.id;
    if (!workout.any((e) => e.sets.any(isOpen))) return null;

    final single = restAfterCompletingInExercise(
      set,
      exercise,
      settings,
      context,
      customRestSeconds: customRestSeconds,
    );
    final group = exercise.supersetGroupId;
    if (customRestSeconds != null ||
        group == null ||
        set.isWarmup ||
        _hasFollowingSidePartner(set, exercise) ||
        _followingSubSet(set, exercise) != null) {
      return single;
    }
    final partners = workout
        .where((e) => e.supersetGroupId == group && e.id != exercise.id)
        .toList();
    if (partners.isEmpty) return single;

    final round = exercise.workingSetNumber(set);
    final partnerHasSetThisRound = partners.any(
      (partner) => partner.sets.any(
        (s) => !s.isWarmup && isOpen(s) && partner.workingSetNumber(s) <= round,
      ),
    );
    if (partnerHasSetThisRound) {
      final transition = settings.supersetTransitionRestSeconds;
      return transition != null && transition > 0 ? transition : null;
    }

    final base = baseRestDuration(settings, context, reps: set.reps);
    if ([exercise, ...partners].any((e) => e.sets.any(isOpen))) return base;
    if (!settings.restBetweenExercises) return null;
    return _scale(base, settings.betweenExercisesRestScaling);
  }

  static WorkoutSet? _byId(WorkoutExercise exercise, String? id) =>
      exercise.sets.where((s) => s.id == id).firstOrNull;

  /// Scaling to nothing is no rest.
  static int? _scale(int base, double factor) {
    final scaled = (base * factor).round();
    return scaled > 0 ? scaled : null;
  }

  /// The next drop or mini-set of the set [set] belongs to, after [set].
  static WorkoutSet? _followingSubSet(
    WorkoutSet set,
    WorkoutExercise exercise,
  ) {
    final parentId = set.parentSetId ?? set.id;
    final position = exercise.sets.indexWhere((s) => s.id == set.id);
    if (position < 0) return null;
    return exercise.sets
        .skip(position + 1)
        .where((s) => s.parentSetId == parentId)
        .firstOrNull;
  }

  /// The breath before [subSet], by its kind or its plain parent's.
  static int? _intraSetRest(
    WorkoutSet subSet,
    WorkoutExercise exercise,
    WorkoutSettings settings,
  ) {
    final parentKind =
        _byId(exercise, subSet.parentSetId)?.kind ?? SetKind.standard;
    final kind = subSet.kind == SetKind.standard ? parentKind : subSet.kind;
    final seconds = settings.intraSetRest(kind);
    return seconds != null && seconds > 0 ? seconds : null;
  }

  static bool _hasFollowingSidePartner(
    WorkoutSet set,
    WorkoutExercise exercise,
  ) =>
      set.side == SetSide.left &&
      pairedSetIds(exercise.sets, set.id).length == 2;

  static bool _isLastWarmup(WorkoutSet set, WorkoutExercise exercise) =>
      exercise.sets.where((s) => s.isWarmup).lastOrNull?.id == set.id;

  static bool _isLastWorkingSet(WorkoutSet set, WorkoutExercise exercise) =>
      exercise.sets.where((s) => !s.isWarmup && !s.isSubSet).lastOrNull?.id ==
      set.id;
}

/// What stops a set being logged (`SetValidation.problem`); the app words it.
enum SetProblem { noReps, noTime, negativeWeight, noDistance }

/// What a set needs before it can be logged (`SetValidation`).
abstract final class SetValidation {
  /// What stops [set] being logged, or `null` when it can be. Only an
  /// assisted exercise may log a weight below zero.
  static SetProblem? problem(
    WorkoutSet set,
    TrackingMode trackingMode, {
    bool isAssisted = false,
  }) {
    bool positive(num? value) => (value ?? 0) > 0;
    if (set.isTimedPiece) {
      return positive(set.durationSec) ? null : SetProblem.noTime;
    }
    switch (trackingMode) {
      case TrackingMode.weightReps:
        final weight = set.weightKg;
        if (!isAssisted && weight != null && weight < 0) {
          return SetProblem.negativeWeight;
        }
        return positive(set.reps) ? null : SetProblem.noReps;
      case TrackingMode.repsOnly:
        return positive(set.reps) ? null : SetProblem.noReps;
      case TrackingMode.timeOnly:
        return positive(set.durationSec) ? null : SetProblem.noTime;
      case TrackingMode.distanceTime:
        if (!positive(set.distanceMeters)) return SetProblem.noDistance;
        return positive(set.durationSec) ? null : SetProblem.noTime;
    }
  }

  static bool canLog(
    WorkoutSet set,
    TrackingMode trackingMode, {
    bool isAssisted = false,
  }) => problem(set, trackingMode, isAssisted: isAssisted) == null;
}
