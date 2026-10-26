import 'package:compound_models/compound_models.dart' as m;
import 'package:notifications_repository/notifications_repository.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart'
    show DistanceUnit, rulesSession;

/// What the Live Activity shows of [session] (Swift
/// `LiveActivityManager.makeContentState`): the exercise at
/// [currentExerciseIndex], or the next with work left, its target set and
/// where it is, the whole workout's progress, the rest running to [restEnd],
/// and the set logged last while that rest runs, each weight in its own
/// exercise's [weightUnit]. [plansSets] is Workout
/// Settings › Set Plan: on, a set worked in pieces counts once its last
/// piece is logged, and the target names its kind and piece.
LiveActivityState liveActivityState({
  required m.WorkoutSessionModel session,
  required bool isActive,
  required int currentExerciseIndex,
  required DateTime now,
  required m.ExerciseWeightUnit Function(m.WorkoutExerciseModel) weightUnit,
  required DistanceUnit Function(m.WorkoutExerciseModel) distanceUnit,
  DateTime? restEnd,
  bool plansSets = false,
}) {
  final exercises = rulesSession(session).exercises;
  final total = exercises.fold(
    0,
    (sum, e) => sum + r.pairedSetCount(e.workingSets),
  );
  final completed = exercises.fold(
    0,
    (sum, e) =>
        sum +
        r.fullyCompletedPairedSetCount(
          plansSets ? countingPieces(e.workingSets) : e.workingSets,
        ),
  );
  final rows = [for (final e in exercises) ...e.sets];
  final index = exerciseIndexWithWorkLeft(currentExerciseIndex, exercises);
  final current = index >= 0 && index < exercises.length
      ? exercises[index]
      : null;
  final model = current == null ? null : session.exercises[index];
  final sets = current?.sets ?? const <r.WorkoutSet>[];
  final target = sets.where((s) => s.completedAt == null).firstOrNull;
  final position = exercisePosition(sets, plansSets: plansSets);
  final piece = plansSets && target != null ? pieceOf(target, sets) : null;
  final resting = restEnd != null && restEnd.isAfter(now);
  final logged = resting ? _lastLogged(exercises) : null;
  final side = target == null || target.isWarmup ? null : target.side?.initial;
  return LiveActivityState(
    isActive: isActive,
    completedSetsCount: completed,
    totalSetsCount: total,
    currentExerciseName: current?.name,
    currentExerciseImageName: current?.imageName,
    currentExerciseIndex: index,
    totalExercisesCount: exercises.length,
    currentExerciseCompletedSetsCount: position.completed,
    currentExerciseTotalSetsCount: position.total,
    targetIsWarmup: position.isWarmup,
    targetSetId: target?.id,
    targetWeightKg: target?.loadKg,
    targetReps: target?.reps,
    targetDistanceMeters: target?.distanceMeters,
    targetDurationSec: target?.durationSec,
    weightUnit: liveActivityWeightUnit(
      model == null ? null : weightUnit(model),
    ),
    distanceUnit: model == null
        ? null
        : LiveActivityDistanceUnit.values.byName(distanceUnit(model).name),
    restEndsAt: restEnd,
    progress:
        piece?.progress(completedSets: completed, totalSets: total) ??
        (total > 0 ? completed / total : 0),
    isAllSetsComplete:
        rows.isNotEmpty && rows.every((s) => s.completedAt != null),
    lastLoggedSetId: logged?.set.id,
    lastLoggedReps: logged?.set.reps,
    lastLoggedWeightKg: logged?.set.loadKg,
    lastLoggedWeightUnit: logged == null
        ? null
        : liveActivityWeightUnit(weightUnit(session.exercises[logged.index])),
    restLeadsToNewExercise: logged != null && logged.index != index,
    targetSide: side == null || side.isEmpty ? null : side,
    // Only an assisted exercise's keypad can enter a negative weight, so
    // one is read as assistance; the tracker's own rule checks the library
    // when Complete is tapped.
    canComplete:
        target != null &&
        r.SetValidation.canLog(
          target,
          current!.trackingMode,
          isAssisted: (target.weightKg ?? 0) < 0,
        ),
    targetKind: plansSets && target != null ? kindOf(target, sets) : null,
    targetPiece: piece,
  );
}

/// The Live Activity's name for [unit]; kilograms when there is none.
LiveActivityWeightUnit liveActivityWeightUnit(m.ExerciseWeightUnit? unit) =>
    unit == m.ExerciseWeightUnit.pounds
    ? LiveActivityWeightUnit.pounds
    : LiveActivityWeightUnit.kilograms;

/// The set logged most recently anywhere, with its exercise's index.
({int index, r.WorkoutSet set})? _lastLogged(
  List<r.WorkoutExercise> exercises,
) {
  ({int index, r.WorkoutSet set})? latest;
  for (final (i, exercise) in exercises.indexed) {
    for (final set in exercise.sets) {
      final at = set.completedAt;
      if (at == null) continue;
      if (latest == null || at.isAfter(latest.set.completedAt!)) {
        latest = (index: i, set: set);
      }
    }
  }
  return latest;
}

/// [requested] while it has a set to log, else the first later exercise
/// with one, else the first anywhere, and only then [requested]
/// (`exerciseIndexWithWorkLeft`).
int exerciseIndexWithWorkLeft(int requested, List<r.WorkoutExercise> list) {
  bool hasWorkLeft(int i) => list[i].sets.any((s) => s.completedAt == null);
  if (requested < 0 || requested >= list.length || hasWorkLeft(requested)) {
    return requested;
  }
  for (var i = requested + 1; i < list.length; i++) {
    if (hasWorkLeft(i)) return i;
  }
  for (var i = 0; i < list.length; i++) {
    if (hasWorkLeft(i)) return i;
  }
  return requested;
}

/// "Warmup 1 of 2" while a warm-up is next, "Set 1 of 4" once the working
/// sets start (`exercisePosition`).
({int completed, int total, bool isWarmup}) exercisePosition(
  List<r.WorkoutSet> sets, {
  bool plansSets = false,
}) {
  final isWarmup =
      sets.where((s) => s.completedAt == null).firstOrNull?.isWarmup ?? false;
  final group = [
    for (final set in plansSets ? countingPieces(sets) : sets)
      if (set.isWarmup == isWarmup) set,
  ];
  return (
    completed: r.fullyCompletedPairedSetCount(group),
    total: r.pairedSetCount(group),
    isWarmup: isWarmup,
  );
}

/// [sets] with every set whose drops or mini-sets are not all logged read as
/// not logged, so a set counts as done once its last piece is.
List<r.WorkoutSet> countingPieces(List<r.WorkoutSet> sets) {
  final open = {
    for (final set in sets)
      if (set.isSubSet && set.completedAt == null) set.parentSetId,
  };
  if (open.isEmpty) return sets;
  return [
    for (final set in sets)
      set.copyWith(completedAt: open.contains(set.id) ? null : set.completedAt),
  ];
}

/// Where [target] is among its set's pieces, or null for a set with none
/// after it.
LiveActivityPiece? pieceOf(r.WorkoutSet target, List<r.WorkoutSet> sets) {
  final parentId = target.parentSetId ?? target.id;
  final parent = sets.where((s) => s.id == parentId).firstOrNull;
  if (parent == null) return null;
  final subSets = r.ActiveWorkout.subSets(parentId, sets);
  final pieces = [parent, ...subSets];
  final position = pieces.indexWhere((s) => s.id == target.id);
  if (subSets.isEmpty || position < 0) return null;
  final word = target.isSubSet ? target : subSets.first;
  const techniques = {r.SetKind.partials, r.SetKind.stretch, r.SetKind.hold};
  return LiveActivityPiece(
    index: position + 1,
    count: pieces.length,
    isDrop: r.subSetKindOf(word) == r.SubSetKind.drop,
    technique: techniques.contains(word.kind)
        ? LiveActivitySetKind.values.byName(word.kind.name)
        : null,
  );
}

/// The kind of the set [target] is, or of the set it is a piece of; null
/// for a plain set.
LiveActivitySetKind? kindOf(r.WorkoutSet target, List<r.WorkoutSet> sets) {
  final parent =
      sets.where((s) => s.id == target.parentSetId).firstOrNull ?? target;
  return parent.kind == r.SetKind.standard
      ? null
      : LiveActivitySetKind.values.byName(parent.kind.name);
}
