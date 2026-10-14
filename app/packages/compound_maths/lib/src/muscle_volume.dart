/// Hard sets per muscle (`MuscleVolume.swift`).
library;

import 'package:compound_maths/src/day_key.dart';
import 'package:compound_maths/src/workout.dart';

/// The muscles an exercise can train (`Muscles.swift`), named by their stored
/// raw values.
enum Muscle {
  triceps,
  upperTraps,
  obliques,
  neck,
  lats,
  forearms,
  sideDelts,
  rearDelts,
  frontDelts,
  chest,
  biceps,
  upperBack,
  lowerBack,
  abs,
  serratus,
  quads,
  hamstrings,
  glutes,
  calves,
  abductors,
  adductors,
  tibialis,
}

/// How an exercise trains a muscle (`MuscleTargetType`).
enum MuscleTarget { primary, secondary }

/// The constants of the hard-set rule (`MuscleVolume.swift`).
abstract final class MuscleVolume {
  /// A set logged below this RPE does not count. Compound's own cut-off.
  static const minimumHardSetRpe = 6.0;

  /// What each drop or mini-set adds to its set.
  static const miniSetCredit = 0.5;

  /// The most one set and its drops or mini-sets can count for.
  static const maximumCreditPerSet = 2.0;

  /// A muscle trained directly gets the whole set; one assisting gets half.
  static double factor(MuscleTarget target) =>
      target == MuscleTarget.secondary ? 0.5 : 1;
}

/// A finished working set taken close enough to failure to count; a set with no
/// RPE counts.
bool isHardSet(WorkoutSet set) {
  if (set.isWarmup || !set.completed) return false;
  final rpe = set.rpe;
  return rpe == null || rpe >= MuscleVolume.minimumHardSetRpe;
}

double _credit(WorkoutSet set, List<WorkoutSet> sets) {
  final extras = sets.where(
    (piece) =>
        piece.parentSetId != null &&
        piece.parentSetId == set.id &&
        !piece.isWarmup &&
        piece.completed &&
        (piece.kind == SetKind.drop ||
            set.kind == SetKind.myo ||
            set.kind == SetKind.restPause),
  );
  final credit = 1 + MuscleVolume.miniSetCredit * extras.length;
  return credit < MuscleVolume.maximumCreditPerSet
      ? credit
      : MuscleVolume.maximumCreditPerSet;
}

/// The hard sets in one logged exercise (`MuscleVolume.hardSets`).
///
/// Each hard set counts 1, plus 0.5 per finished drop (or mini-set of a myo-rep
/// or rest-pause set), up to 2. A left/right pair is one set worth its better
/// half; the pair is the row before, hard or not, so a right side after an easy
/// left is worth its own credit.
double hardSets(WorkoutExercise exercise) {
  final sets = exercise.sets;
  var total = 0.0;
  ({SetSide? side, double credit})? previous;
  for (final set in sets) {
    if (set.isWarmup || !set.completed || set.isSubSet) continue;
    final value = isHardSet(set) ? _credit(set, sets) : 0.0;
    if (set.side == SetSide.right && previous?.side == SetSide.left) {
      final extra = value - previous!.credit;
      total += extra > 0 ? extra : 0;
    } else {
      total += value;
    }
    previous = (side: set.side, credit: value);
  }
  return total;
}

/// Weighted hard sets per muscle in [weeks] rolling seven-day windows, oldest
/// first, the last ending on [endDay] (`MuscleVolume.weeklySets`). Every muscle
/// is present, zero-filled.
///
/// [templates] maps a template id to the muscles it trains. Sessions are
/// bucketed by their [WorkoutSession.day].
Map<Muscle, List<double>> weeklyMuscleSets(
  List<WorkoutSession> sessions,
  Map<String, Map<Muscle, MuscleTarget>> templates,
  String endDay, {
  int weeks = 12,
}) {
  final result = {
    for (final muscle in Muscle.values) muscle: List<double>.filled(weeks, 0),
  };
  for (final session in sessions) {
    final daysAgo = daysBetween(session.day, endDay);
    if (daysAgo < 0 || daysAgo >= weeks * 7) continue;
    final bucket = weeks - 1 - daysAgo ~/ 7;
    for (final exercise in session.exercises) {
      final groups = templates[exercise.templateId];
      if (groups == null) continue;
      final sets = hardSets(exercise);
      if (sets <= 0) continue;
      groups.forEach((muscle, target) {
        result[muscle]![bucket] += sets * MuscleVolume.factor(target);
      });
    }
  }
  return result;
}
