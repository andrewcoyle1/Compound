/// Smart progression: double progression with a load step that is a share of
/// the working weight, resets from the estimated one-rep max, AMRAP targets,
/// the mesocycle deload and how a session is prefilled
/// (`Compound/Managers/Training/Progression/*`,
/// `WorkoutSessionModel+Prefill.swift`). Sources and Compound's own choices:
/// `MethodInfo.smartProgression`, `MethodInfo.mesocycleDeload`.
library;

import 'dart:math' as math;

import 'package:compound_maths/compound_maths.dart' show estimatedOneRepMax;
import 'package:equatable/equatable.dart';
import 'package:training_rules/src/models.dart';

/// Where RPE and RIR meet: RIR = 10 − RPE (`EffortScale.swift`).
abstract final class EffortScale {
  /// None to six or more; six or more is stored as six, an RPE of 4.
  static const rirChoices = [0, 1, 2, 3, 4, 5, 6];

  /// "2", or "6+" for the last choice.
  static String rirText(int rir) => rir >= 6 ? '6+' : '$rir';

  /// The reps in reserve a logged RPE reads as, to the nearest rep, at most 6.
  static int rirChoice(double rpe) => rirFromRpe(rpe).round().clamp(0, 6);

  static double rirFromRpe(double rpe) => 10 - rpe;

  static double rpeFromRir(int rir) => 10 - rir.toDouble();
}

/// How big a step up in weight is, and how hard a set may be logged before
/// it earns one (`LoadIncrement.swift`).
abstract final class LoadIncrement {
  /// The share of the working weight to add, inside ACSM's 2–10 %: lower-body
  /// compounds 5 %, upper-body compounds (and no type) 2.5 %, isolation and
  /// core 5 %.
  static double targetFraction(ExerciseType? type) => switch (type) {
    ExerciseType.compoundUpper || null => 0.025,
    _ => 0.05,
  };

  /// A smallest step bigger than this share is too big a jump.
  static const maximumFraction = 0.10;

  /// The reps in reserve a compound lift is held to without a target.
  static int? defaultReserve(ExerciseType? type) => switch (type) {
    ExerciseType.compoundUpper || ExerciseType.compoundLower => 1,
    _ => null,
  };

  /// The reps in reserve a reset aims for without a target.
  static const resetReserve = 2;

  /// A reset is kept between 5 % and 15 % under the weight missed.
  static const resetFloorFraction = 0.85;
  static const resetCeilingFraction = 0.95;

  /// Without an estimate, a reset takes ten per cent off.
  static const resetFallbackFraction = 0.90;

  /// A miss logged under this RPE was stopped short, not failed.
  static const resetMinimumRpe = 9.5;
}

/// The load for [reps] with [reserve] reps left, from a one-rep max: Epley
/// turned round (`ExerciseOneRMAggregator.load(forOneRepMax:)`).
double loadForOneRepMax(double oneRepMaxKg, int reps, double reserve) {
  final toFailure = math.max(reps, 1) + math.max(reserve, 0.0);
  if (toFailure <= 1) return oneRepMaxKg;
  return oneRepMaxKg / (1 + toFailure / 30);
}

/// One suggested set; each field only where the mode tracks it
/// (`SuggestedSet`).
class const SuggestedSet({
  final double? weightKg,
  final int? reps,
  final int? durationSec,
  final double? distanceMeters,

  /// An AMRAP set's target for the session (set plan only).
  final int? targetReps,
}) extends Equatable {
  /// Nothing to suggest.
  static const none = SuggestedSet();

  bool get isEmpty =>
      weightKg == null &&
      reps == null &&
      durationSec == null &&
      distanceMeters == null &&
      targetReps == null;

  @override
  List<Object?> get props => [
    weightKg,
    reps,
    durationSec,
    distanceMeters,
    targetReps,
  ];
}

/// Why a suggestion looks the way it does.
enum Rationale { noHistory, progressWeight, addReps, hold, deload }

/// What the engine decided for one exercise, and one set per working set
/// (`ProgressionSuggestion`).
class const ProgressionSuggestion(
  final Rationale rationale,
  final List<SuggestedSet> sets,
) extends Equatable {
  /// For an exercise with nothing to progress from.
  factory noHistory(int setCount) => ProgressionSuggestion(
    Rationale.noHistory,
    List.filled(math.max(setCount, 0), SuggestedSet.none),
  );

  /// The suggestion for set [index], `null` past the end or when empty.
  SuggestedSet? setAt(int index) {
    if (index < 0 || index >= sets.length) return null;
    final suggested = sets[index];
    return suggested.isEmpty ? null : suggested;
  }

  /// The suggestion for [set], a row of [exercise], matched on its working
  /// set number so both halves of a pair read the same one; none for a
  /// warm-up (`ProgressionSuggestionDisplay.swift`).
  SuggestedSet? suggestedSetFor(WorkoutSet set, WorkoutExercise exercise) =>
      set.isWarmup ? null : setAt(exercise.workingSetNumber(set) - 1);

  @override
  List<Object?> get props => [rationale, sets];
}

/// What a weight may be: a rounding rule and its smallest step, in kg.
class const ProgressionRounding({
  required final double Function(double) round,
  required final double minimumIncrementKg,
});

/// Everything the engine is given for one exercise (`ProgressionInput`).
class const ProgressionInput({
  required final TrackingMode trackingMode,
  required final List<SetTarget> setTargets,

  /// Completed working sets per past session, most recent first, at most
  /// three.
  required final List<List<WorkoutSet>> history,
  required final ProgressionAdjustmentMode adjustmentMode,
  required final ProgressionRounding rounding,
  final AmrapProgression? amrap,
  final ExerciseType? exerciseType,
});

/// How an AMRAP set with a target progresses under the set plan
/// (`AMRAPProgression.swift`).
class const AmrapProgression({
  /// The target at which beating it adds weight rather than a rep; `null`
  /// never adds weight.
  final int? ceiling,
}) extends Equatable {
  /// The rule [settings] run, or `null` with the set plan or the rule off.
  static AmrapProgression? fromSettings(WorkoutSettings settings) =>
      settings.plansSets && settings.raisesAmrapTarget
      ? AmrapProgression(
          ceiling: settings.addsWeightAtAmrapTarget
              ? settings.amrapWeightCeiling
              : null,
        )
      : null;

  /// Next session's AMRAP set: the target rises a rep once beaten twice
  /// running at one weight; at the ceiling the set adds weight instead and
  /// the target returns to [templateTarget].
  SuggestedSet next({
    required int templateTarget,
    required WorkoutSet last,
    required WorkoutSet? previous,
    required double Function(double) heavier,
  }) {
    final target = last.targetReps ?? templateTarget;
    bool beat(WorkoutSet? set) => set?.reps != null && set!.reps! > target;
    final beatenTwice =
        previous?.weightKg == last.weightKg && beat(last) && beat(previous);
    if (!beatenTwice) {
      return SuggestedSet(
        weightKg: last.weightKg,
        reps: target,
        targetReps: target,
      );
    }
    final limit = ceiling;
    final weight = last.weightKg;
    if (limit != null && target >= limit && weight != null) {
      return SuggestedSet(
        weightKg: heavier(weight),
        reps: templateTarget,
        targetReps: templateTarget,
      );
    }
    return SuggestedSet(
      weightKg: last.weightKg,
      reps: target + 1,
      targetReps: target + 1,
    );
  }

  @override
  List<Object?> get props => [ceiling];
}

typedef _RepRange = ({int min, int max, bool isPrescribed});

/// Double progression, in the only place it is decided
/// (`ProgressionEngine.swift`). Pure: rounding arrives as a function.
abstract final class ProgressionEngine {
  /// What to suggest for every working set of one exercise at session start.
  static ProgressionSuggestion suggest(ProgressionInput input) {
    final reference = input.history.firstOrNull;
    if (reference == null || reference.isEmpty) {
      return ProgressionSuggestion.noHistory(input.setTargets.length);
    }
    return switch (input.trackingMode) {
      TrackingMode.weightReps ||
      TrackingMode.repsOnly => _suggestRepBased(input, reference),
      TrackingMode.timeOnly ||
      TrackingMode.distanceTime => _suggestMeasured(input, reference),
    };
  }

  /// Re-suggests the sets still to come from the one just logged; `null`
  /// leaves a set as it is.
  static List<SuggestedSet?> adjustRemaining({
    required WorkoutSet completed,
    required SetTarget? target,
    required List<WorkoutSet> remaining,
    required TrackingMode mode,
    required ProgressionRounding rounding,
    ExerciseType? exerciseType,
  }) {
    final unchanged = List<SuggestedSet?>.filled(remaining.length, null);
    final reps = completed.reps;
    final weight = completed.weightKg;
    if (mode != TrackingMode.weightReps || reps == null || weight == null) {
      return unchanged;
    }
    final range = _repRange(target);
    final SuggestedSet adjusted;
    if (reps < range.min - 1 && range.isPrescribed) {
      adjusted = SuggestedSet(
        weightKg: _lighterWeight(weight, rounding),
        reps: range.min,
      );
    } else if (reps == range.min - 1 && range.isPrescribed) {
      adjusted = SuggestedSet(weightKg: weight, reps: range.min);
    } else if (reps >= range.max + 2 && (completed.rpe ?? 0) <= 8) {
      final heavier = _increasedWeight(
        weight,
        LoadIncrement.targetFraction(exerciseType),
        rounding,
      );
      if (!(heavier > weight) ||
          !_jumpIsAffordable(weight, reps, heavier, range.min)) {
        return unchanged;
      }
      adjusted = SuggestedSet(weightKg: heavier, reps: range.min);
    } else {
      return unchanged;
    }
    return List.filled(remaining.length, adjusted);
  }

  /// Five per cent off, rounded so it is lighter; more help for assistance.
  static double _lighterWeight(double weight, ProgressionRounding rounding) {
    final intended = weight >= 0 ? weight * 0.95 : weight * 1.05;
    final rounded = rounding.round(intended);
    if (rounded < weight - 0.001) return rounded;
    return rounding.round(weight - rounding.minimumIncrementKg);
  }

  static ProgressionSuggestion _suggestRepBased(
    ProgressionInput input,
    List<WorkoutSet> reference,
  ) {
    final classified = _classify(input, reference);
    final tracksWeight = input.trackingMode == TrackingMode.weightReps;
    final fraction = LoadIncrement.targetFraction(input.exerciseType);
    var heavierSets = 0;
    var repsInsteadSets = 0;

    SuggestedSet suggestion(int index) {
      final setTarget = _target(input, index);
      final previousSet = _referenceSet(reference, index);
      final referenceWeight = tracksWeight ? previousSet?.weightKg : null;
      final referenceReps = previousSet?.reps;
      final range = _repRange(setTarget);

      // An AMRAP set with a planned target follows its own rule.
      final amrap = input.amrap;
      final templateTarget = setTarget?.amrapTargetReps;
      if (amrap != null &&
          setTarget != null &&
          previousSet != null &&
          SetKind.fromSetType(setTarget.setType) == SetKind.amrap &&
          templateTarget != null) {
        final earlier = input.history.length > 1
            ? _referenceSet(input.history[1], index)
            : null;
        return amrap.next(
          templateTarget: templateTarget,
          last: previousSet,
          previous: earlier,
          heavier: (w) => _increasedWeight(w, fraction, input.rounding),
        );
      }

      // An intensity technique is prefilled but never progressed.
      if (!_isProgressable(setTarget)) {
        return SuggestedSet(weightKg: referenceWeight, reps: referenceReps);
      }

      switch (classified) {
        case Rationale.progressWeight when !tracksWeight:
          return SuggestedSet(reps: (referenceReps ?? range.max) + 1);
        case Rationale.progressWeight:
          final progressed = _progressedSet(
            referenceWeight,
            referenceReps,
            range,
            fraction,
            input.rounding,
          );
          if (progressed.weightKg == referenceWeight) {
            repsInsteadSets++;
          } else {
            heavierSets++;
          }
          return progressed;
        case Rationale.addReps:
          return SuggestedSet(
            weightKg: referenceWeight,
            reps: referenceReps == null
                ? range.min
                : math.min(referenceReps + 1, range.max),
          );
        case Rationale.deload:
          final lighter = previousSet == null
              ? null
              : _resetWeight(previousSet, setTarget, range.min, input);
          return SuggestedSet(
            weightKg: tracksWeight ? lighter : null,
            reps: range.min,
          );
        // `_classify` never answers `noHistory`; it is grouped with `hold`.
        case Rationale.hold || Rationale.noHistory:
          return SuggestedSet(weightKg: referenceWeight, reps: referenceReps);
      }
    }

    final sets = [
      for (var i = 0; i < _setCount(input, reference); i++) suggestion(i),
    ];
    // Every set that would have added weight took a rep instead.
    final rationale =
        classified == Rationale.progressWeight &&
            tracksWeight &&
            heavierSets == 0 &&
            repsInsteadSets > 0
        ? Rationale.addReps
        : classified;
    return ProgressionSuggestion(rationale, sets);
  }

  /// A miss twice running at the same weight or heavier is a pattern; once is
  /// a bad day.
  static Rationale _classify(
    ProgressionInput input,
    List<WorkoutSet> reference,
  ) {
    final previous = input.history.length > 1 ? input.history[1] : null;

    if (_tally(input, reference).missed > 0) {
      if (previous != null &&
          _heaviestWeight(previous) >= _heaviestWeight(reference) &&
          _failedMisses(input, reference) > 0 &&
          _failedMisses(input, previous) > 0) {
        return Rationale.deload;
      }
      return Rationale.hold;
    }

    if (!_rpeWithinTarget(input, reference) || !_reachedTop(input, reference)) {
      return Rationale.addReps;
    }

    // Without an RPE the top must be reached on two sessions running at this
    // weight (ACSM 2009).
    if (!reference.any((set) => set.rpe != null)) {
      if (previous == null ||
          _heaviestWeight(previous) < _heaviestWeight(reference) ||
          !_reachedTop(input, previous)) {
        return Rationale.addReps;
      }
    }
    return Rationale.progressWeight;
  }

  /// Weight-first takes a majority of sets at the top; reps-first wants all.
  static bool _reachedTop(ProgressionInput input, List<WorkoutSet> session) {
    final top = _tally(input, session).top;
    final count = _judged(input, session).length;
    return switch (input.adjustmentMode) {
      ProgressionAdjustmentMode.weightFirst => top * 2 > count,
      ProgressionAdjustmentMode.repsFirst => top == count,
    };
  }

  /// The sets judged: those whose target progresses.
  static List<(int, WorkoutSet)> _judged(
    ProgressionInput input,
    List<WorkoutSet> session,
  ) => [
    for (final (index, set) in session.indexed)
      if (_isProgressable(_target(input, index))) (index, set),
  ];

  /// Misses below a prescribed range not stopped short on purpose.
  static int _failedMisses(ProgressionInput input, List<WorkoutSet> session) =>
      _judged(input, session).where((entry) {
        final (index, set) = entry;
        final reps = set.reps;
        if (reps == null) return false;
        final range = _repRange(_target(input, index));
        return range.isPrescribed &&
            reps < range.min &&
            (set.rpe == null || set.rpe! >= LoadIncrement.resetMinimumRpe);
      }).length;

  static ({int top, int missed}) _tally(
    ProgressionInput input,
    List<WorkoutSet> session,
  ) {
    var top = 0;
    var missed = 0;
    for (final (index, set) in _judged(input, session)) {
      final reps = set.reps;
      if (reps == null) continue;
      final range = _repRange(_target(input, index));
      if (reps >= range.max) top++;
      if (reps < range.min && range.isPrescribed) missed++;
    }
    return (top: top, missed: missed);
  }

  /// False when any set was logged harder than prescribed.
  static bool _rpeWithinTarget(
    ProgressionInput input,
    List<WorkoutSet> session,
  ) {
    for (final (index, set) in _judged(input, session)) {
      final rpe = set.rpe;
      final rir =
          _target(input, index)?.effectiveRirTarget ??
          LoadIncrement.defaultReserve(input.exerciseType);
      if (rpe == null || rir == null) continue;
      if (rpe > EffortScale.rpeFromRir(rir) + 0.5) return false;
    }
    return true;
  }

  static double _heaviestWeight(List<WorkoutSet> session) =>
      session
          .map((set) => set.weightKg)
          .nonNulls
          .fold<double?>(null, (a, b) => a == null || b > a ? b : a) ??
      0;

  /// Timed and distance work: progress when every planned set was finished.
  static ProgressionSuggestion _suggestMeasured(
    ProgressionInput input,
    List<WorkoutSet> reference,
  ) {
    final allCompleted =
        reference.every((set) => set.completedAt != null) &&
        reference.length >= input.setTargets.length;

    SuggestedSet suggestion(int index) {
      final previousSet = _referenceSet(reference, index);
      final duration = previousSet?.durationSec;
      final distance = previousSet?.distanceMeters;
      if (!allCompleted || !_isProgressable(_target(input, index))) {
        return SuggestedSet(durationSec: duration, distanceMeters: distance);
      }
      if (input.trackingMode == TrackingMode.timeOnly) {
        // Ten per cent on the nearest 5 s, and never less than 5 s more.
        return SuggestedSet(
          durationSec: duration == null
              ? null
              : math.max(_roundTo(duration * 1.10, 5).toInt(), duration + 5),
          distanceMeters: distance,
        );
      }
      // Five per cent on a step that suits the distance, at least that step.
      double? further;
      if (distance != null) {
        final step = distance < 200
            ? 1.0
            : distance < 2000
            ? 10.0
            : 50.0;
        further = math.max(_roundTo(distance * 1.05, step), distance + step);
      }
      return SuggestedSet(durationSec: duration, distanceMeters: further);
    }

    return ProgressionSuggestion(
      allCompleted ? Rationale.progressWeight : Rationale.hold,
      [for (var i = 0; i < _setCount(input, reference); i++) suggestion(i)],
    );
  }

  static int _setCount(ProgressionInput input, List<WorkoutSet> reference) =>
      math.max(reference.length, input.setTargets.length);

  /// The last target applies past the end of the list.
  static SetTarget? _target(ProgressionInput input, int index) =>
      index < input.setTargets.length
      ? input.setTargets[index]
      : input.setTargets.lastOrNull;

  /// Set `i` progresses from its own reference set.
  static WorkoutSet? _referenceSet(List<WorkoutSet> reference, int index) =>
      index < reference.length ? reference[index] : reference.lastOrNull;

  /// The template's range, one end widened by the default width, else the
  /// default range, which is not prescribed and so cannot be missed.
  static _RepRange _repRange(SetTarget? target) {
    const width = SetTarget.defaultRangeWidth;
    return switch ((target?.minReps, target?.maxReps)) {
      (final int low, final int high) => (
        min: low,
        max: math.max(low, high),
        isPrescribed: true,
      ),
      (final int low, null) => (min: low, max: low + width, isPrescribed: true),
      (null, final int high) => (
        min: math.max(1, high - width),
        max: high,
        isPrescribed: true,
      ),
      (null, null) => (
        min: SetTarget.defaultRepRangeMin,
        max: SetTarget.defaultRepRangeMax,
        isPrescribed: false,
      ),
    };
  }

  static bool _isProgressable(SetTarget? target) => switch (target?.setType) {
    null ||
    SetTargetSetType.standard ||
    SetTargetSetType.failure ||
    SetTargetSetType.amrap => true,
    _ => false,
  };

  /// Adds [fraction] of the weight, at least one increment, and rounds; where
  /// rounding swallows the step whole it adds twice the step. Assistance
  /// steps by the increment alone.
  static double _increasedWeight(
    double weight,
    double fraction,
    ProgressionRounding rounding,
  ) {
    final step = math.max(
      weight > 0 ? weight * fraction : 0.0,
      rounding.minimumIncrementKg,
    );
    final once = rounding.round(weight + step);
    if (once > weight) return once;
    return rounding.round(weight + step * 2);
  }

  /// One weighted set under `progressWeight`: heavier at the bottom of the
  /// range, or a rep more where the step is too big or there is nowhere to go.
  static SuggestedSet _progressedSet(
    double? weight,
    int? reps,
    _RepRange range,
    double fraction,
    ProgressionRounding rounding,
  ) {
    final oneMore = (reps ?? range.max) + 1;
    if (weight == null) return SuggestedSet(reps: oneMore);
    final heavier = _increasedWeight(weight, fraction, rounding);
    if (!(heavier > weight + 0.001)) {
      return SuggestedSet(weightKg: weight, reps: oneMore);
    }
    if (reps != null && !_jumpIsAffordable(weight, reps, heavier, range.min)) {
      return SuggestedSet(weightKg: weight, reps: reps + 1);
    }
    return SuggestedSet(weightKg: heavier, reps: range.min);
  }

  /// Within the maximum fraction a step always is affordable; a bigger one
  /// waits until the reps at [weight] carry [heavier] for [minReps] (Epley).
  static bool _jumpIsAffordable(
    double weight,
    int reps,
    double heavier,
    int minReps,
  ) {
    if (!(weight > 0) || !(heavier > weight)) return true;
    if (!((heavier - weight) / weight > LoadIncrement.maximumFraction)) {
      return true;
    }
    return weight * (1 + reps / 30) >= heavier * (1 + minReps / 30);
  }

  /// After two sessions of misses: the weight for the bottom of the range
  /// with reps in reserve, from the estimated one-rep max, kept 5–15 % under
  /// the weight missed; else ten per cent off. Rounded down where the
  /// rounding is ambiguous.
  static double? _resetWeight(
    WorkoutSet set,
    SetTarget? target,
    int minReps,
    ProgressionInput input,
  ) {
    final weight = set.weightKg;
    if (weight == null) return null;
    final load = set.loadKg!;
    final reps = set.reps;
    final oneRepMax = weight > 0 && reps != null
        ? estimatedOneRepMax(load, reps, rpe: set.rpe)
        : null;
    final double intended;
    if (oneRepMax != null) {
      final reserve = (target?.rirTarget ?? LoadIncrement.resetReserve)
          .toDouble();
      final derived = loadForOneRepMax(oneRepMax, minReps, reserve);
      intended = math.min(
        math.max(derived, weight * LoadIncrement.resetFloorFraction),
        weight * LoadIncrement.resetCeilingFraction,
      );
    } else if (weight < 0) {
      intended = weight * (2 - LoadIncrement.resetFallbackFraction);
    } else {
      intended = weight * LoadIncrement.resetFallbackFraction;
    }
    final round = input.rounding.round;
    final rounded = round(intended);
    if (!(rounded > intended + 0.001)) return rounded;
    final lower = round(intended - input.rounding.minimumIncrementKg);
    return lower <= intended && (lower > 0 || weight <= 0) ? lower : rounded;
  }

  static double _roundTo(double value, double step) =>
      (value / step).roundToDouble() * step;
}

/// A mesocycle's deload week: about half the working sets at 90 % of the
/// planned weight, reps as planned (`MesocycleDeload.swift`).
abstract final class MesocycleDeload {
  static const setFraction = 0.5;
  static const loadFraction = 0.90;

  /// Working sets to keep out of [planned], rounded up, at least one.
  static int setCount(int planned) =>
      planned <= 0 ? 0 : math.max(1, (planned * setFraction).ceil());

  /// The lighter weight before rounding; more help for assistance.
  static double lighter(double weightKg) =>
      weightKg >= 0 ? weightKg * loadFraction : weightKg * (2 - loadFraction);

  /// [lighter] rounded by [round], and lighter than [weightKg] even where the
  /// nearest weight is the one lifted: up to four steps down are tried.
  static double lighterWeight(double weightKg, double Function(double) round) {
    final drop = weightKg - lighter(weightKg);
    for (var steps = 1; steps <= 4; steps++) {
      final rounded = round(weightKg - drop * steps);
      if (rounded < weightKg - 0.001) return rounded;
    }
    return weightKg;
  }

  /// [sets] with the first [setCount] working sets left, renumbered from one;
  /// a set's drops and its right half go with it, and warm-ups all stay.
  static List<WorkoutSet> keptSets(List<WorkoutSet> sets) {
    final groups = <int>[];
    var group = -1;
    SetSide? previousSide;
    for (final set in sets) {
      if (set.isWarmup) {
        groups.add(-1);
        continue;
      }
      if (!set.isSubSet) {
        if (!(set.side == SetSide.right && previousSide == SetSide.left)) {
          group++;
        }
        previousSide = set.side;
      }
      groups.add(group);
    }
    final keep = setCount(group + 1);
    final kept = [
      for (final (i, set) in sets.indexed)
        if (groups[i] < keep) set,
    ];
    return [
      for (final (offset, set) in kept.indexed) set.copyWith(index: offset + 1),
    ];
  }

  /// A deload session: every exercise cut by [keptSets], every non-zero
  /// weight made [lighterWeight] by its exercise's rounding
  /// (`WorkoutSessionModel.applyDeload`).
  static WorkoutSession apply(
    WorkoutSession session,
    double Function(double) Function(WorkoutExercise) rounding,
  ) => WorkoutSession(
    isDeload: true,
    exercises: [
      for (final exercise in session.exercises)
        exercise.copyWith(
          sets: [
            for (final set in keptSets(exercise.sets))
              if (set.weightKg == null || set.weightKg == 0)
                set
              else
                set.copyWith(
                  weightKg: lighterWeight(set.weightKg!, rounding(exercise)),
                ),
          ],
        ),
    ],
  );
}

/// One exercise, described the way the planner needs it
/// (`ProgressionPlanner.ExerciseContext`). The rounding is resolved by the
/// caller from the gym.
class const ProgressionContext({
  required final String templateId,
  required final TrackingMode trackingMode,
  required final List<SetTarget> setTargets,
  required final ProgressionRounding rounding,
  final ExerciseType? exerciseType,

  /// The equipment the exercise is lifted with this time.
  final List<EquipmentRef>? resistanceEquipment,
  final int occurrence = 0,
}) {
  String get historyKey => historyKeyFor(templateId, occurrence);
}

/// `"<templateId>#<occurrence>"`: the key last time's figures and a
/// suggestion are kept under (`ActiveWorkout.historyKey`).
String historyKeyFor(String templateId, int occurrence) =>
    '$templateId#$occurrence';

/// Gathers an exercise's history out of past sessions and asks the engine
/// (`ProgressionPlanner.swift`).
abstract final class ProgressionPlanner {
  /// A suggestion per context, keyed by its history key; `noHistory` ones
  /// included.
  static Map<String, ProgressionSuggestion> suggestions({
    required List<ProgressionContext> contexts,
    required List<WorkoutSession> history,
    required ProgressionAdjustmentMode adjustmentMode,
    AmrapProgression? amrap,
  }) => {
    for (final context in contexts)
      context.historyKey: ProgressionEngine.suggest(
        ProgressionInput(
          trackingMode: context.trackingMode,
          setTargets: context.setTargets,
          history: historyFor(
            context.templateId,
            history,
            occurrence: context.occurrence,
            loadedWith: context.resistanceEquipment,
          ),
          adjustmentMode: adjustmentMode,
          rounding: context.rounding,
          amrap: amrap,
          exerciseType: context.exerciseType,
        ),
      ),
  };

  /// One exercise's completed working sets per session, most recent first,
  /// at most [limit] deep. Deload weeks, sessions without the exercise's
  /// [occurrence]th appearance, ones lifted with another kind of load and
  /// ones with nothing logged are passed over. [sessions] are most recent
  /// first.
  static List<List<WorkoutSet>> historyFor(
    String templateId,
    List<WorkoutSession> sessions, {
    int occurrence = 0,
    List<EquipmentRef>? loadedWith,
    int limit = 3,
  }) {
    final history = <List<WorkoutSet>>[];
    for (final session in sessions) {
      if (session.isDeload ?? false) continue;
      final exercise = session.exercise(templateId, occurrence);
      if (exercise == null ||
          !isSameLoad(exercise.resistanceEquipment, loadedWith)) {
        continue;
      }
      // A pair's left stands for it; a sub-set is part of its parent.
      final working = exercise.sets
          .where(
            (set) =>
                !set.isWarmup &&
                set.completedAt != null &&
                !set.isSubSet &&
                set.side != SetSide.right,
          )
          .toList();
      if (working.isEmpty) continue;
      history.add(working);
      if (history.length == limit) break;
    }
    return history;
  }
}

/// How a new session's working sets are filled in (`SessionPrefill`).
sealed class SessionPrefill {
  const new();

  /// Whether the working sets are filled in at all.
  bool get fillsWorkingSets => this is! PrefillEmpty;

  /// The suggestion for one exercise, `null` with none or `noHistory`.
  ProgressionSuggestion? suggestionFor(
    String templateId, {
    int occurrence = 0,
  }) {
    final self = this;
    if (self is! PrefillSuggestions) return null;
    final suggestion = self.byExercise[historyKeyFor(templateId, occurrence)];
    return suggestion?.rationale == Rationale.noHistory ? null : suggestion;
  }
}

/// Exactly what was logged last time.
final class PrefillPreviousValues extends SessionPrefill {
  const new();
}

/// Every working set starts blank.
final class PrefillEmpty extends SessionPrefill {
  const new();
}

/// The engine's suggestions by history key; anything missing falls back to
/// the previous values.
final class PrefillSuggestions extends SessionPrefill {
  const new(this.byExercise);

  final Map<String, ProgressionSuggestion> byExercise;
}

/// [workingSets] filled from the suggestion for the exercise, falling back
/// per field to last time; a set with neither stays as built
/// (`WorkingSetPrefill.apply`). Sub-sets are left alone, and last time is
/// read one row per set, a pair's left standing for it. [round] is the
/// exercise's weight rule.
List<WorkoutSet> prefillWorkingSets(
  List<WorkoutSet> workingSets, {
  required SessionPrefill prefill,
  required String templateId,
  required List<WorkoutSet>? previousSets,
  required double Function(double) round,
  int occurrence = 0,
}) {
  if (!prefill.fillsWorkingSets) return workingSets;
  final suggestion = prefill.suggestionFor(templateId, occurrence: occurrence);
  final previousWorking = (previousSets ?? [])
      .where((s) => !s.isWarmup && s.side != SetSide.right && !s.isSubSet)
      .toList();
  var position = 0;
  final filled = <WorkoutSet>[];
  for (final set in workingSets) {
    if (set.isSubSet) {
      filled.add(set);
      continue;
    }
    filled.add(
      _prefilled(
        set,
        suggestion?.setAt(position),
        position < previousWorking.length ? previousWorking[position] : null,
        round,
      ),
    );
    position++;
  }
  return filled;
}

WorkoutSet _prefilled(
  WorkoutSet set,
  SuggestedSet? suggested,
  WorkoutSet? previous,
  double Function(double) round,
) {
  if (suggested == null && previous == null) return set;
  final weight = suggested?.weightKg ?? previous?.weightKg ?? set.weightKg;
  return set.copyWith(
    reps: suggested?.reps ?? previous?.reps ?? set.reps,
    weightKg: weight == null ? null : round(weight),
    bands: previous?.bands ?? set.bands,
    durationSec:
        suggested?.durationSec ?? previous?.durationSec ?? set.durationSec,
    distanceMeters:
        suggested?.distanceMeters ??
        previous?.distanceMeters ??
        set.distanceMeters,
    targetReps: suggested?.targetReps ?? set.targetReps,
    isWarmup: false,
    completedAt: null,
  );
}
