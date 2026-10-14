/// The workout values the rules read, cut down to the fields they use.
///
/// Mirrors `WorkoutSetModel`, `WorkoutExerciseModel`, `WorkoutSessionModel`,
/// `SetTarget`, `WorkoutSettings` and `WorkoutSetPairing.swift`. Firestore
/// shapes are `compound_models`' job; a later slice maps those onto these.
library;

import 'package:equatable/equatable.dart';

/// How an exercise is logged (`TrackingMode.swift`).
enum TrackingMode { weightReps, repsOnly, timeOnly, distanceTime }

/// The library exercise's type (`ExerciseType.swift`).
enum ExerciseType {
  compoundUpper,
  compoundLower,
  isolationUpper,
  isolationLower,
  core,
}

/// The unit an exercise's weight is entered in (`ExerciseWeightUnit`).
enum WeightUnit { kilograms, pounds }

/// Which sets must reach the top before weight goes on.
enum ProgressionAdjustmentMode { weightFirst, repsFirst }

/// Which side of the body a set was worked with (`SetSide.swift`).
enum SetSide {
  left,
  right,
  both;

  /// The marker beside a set number, as in "2L".
  String get initial => switch (this) {
    left => 'L',
    right => 'R',
    both => '',
  };
}

/// The set type a template's target asks for (`SetTargetSetType.swift`).
enum SetTargetSetType {
  standard,
  drop,
  myo,

  /// Written before `amrap` existed; read as an AMRAP set.
  failure,
  amrap,
  restPause,
  cluster,
  partials,
  stretch,
  hold,
}

/// How a set is performed beyond its figures (`SetKind.swift`).
enum SetKind {
  standard,
  drop,
  amrap,
  myo,
  restPause,
  cluster,
  partials,
  stretch,
  hold;

  /// The kind a template's target asks for; a "failure" set is an AMRAP set.
  static SetKind fromSetType(SetTargetSetType type) => switch (type) {
    SetTargetSetType.standard => standard,
    SetTargetSetType.drop => drop,
    SetTargetSetType.myo => myo,
    SetTargetSetType.failure || SetTargetSetType.amrap => amrap,
    SetTargetSetType.restPause => restPause,
    SetTargetSetType.cluster => cluster,
    SetTargetSetType.partials => partials,
    SetTargetSetType.stretch => stretch,
    SetTargetSetType.hold => hold,
  };

  /// Rows of this kind take a breath between them: mini-sets and clusters.
  bool get restsWithinTheSet =>
      this == myo || this == restPause || this == cluster;

  /// A stretch or hold piece is logged as a time.
  bool get isTimed => this == stretch || this == hold;
}

const Object _keep = Object();

/// One logged or planned set row (`WorkoutSetModel`).
///
/// [weightKg] is the total; a plate-loaded machine's [machineBaseKg] kept out
/// of what is entered makes [loadKg] the figure shown.
class const WorkoutSet({
  required final String id,
  final int index = 1,
  final String authorId = '',
  final int? reps,
  final double? weightKg,
  final int? durationSec,
  final double? distanceMeters,
  final double? rpe,
  final SetSide? side,
  final SetKind kind = SetKind.standard,
  final String? parentSetId,
  final int? targetReps,
  final List<String>? bands,
  final WeightUnit? weightUnit,
  final int? loadCount,
  final double? machineBaseKg,
  final bool isWarmup = false,
  final DateTime? completedAt,
}) extends Equatable {
  /// A drop, mini-set or piece of the set named by [parentSetId].
  bool get isSubSet => parentSetId != null;

  /// A stretch or hold after its set, logged as a time.
  bool get isTimedPiece => isSubSet && kind.isTimed;

  /// The weight as entered and shown: the total less a machine base.
  double? get loadKg =>
      weightKg == null ? null : weightKg! - (machineBaseKg ?? 0);

  /// A copy with the given fields replaced; pass `null` to clear a nullable
  /// one.
  WorkoutSet copyWith({
    int? index,
    Object? reps = _keep,
    Object? weightKg = _keep,
    Object? durationSec = _keep,
    Object? distanceMeters = _keep,
    Object? rpe = _keep,
    Object? side = _keep,
    SetKind? kind,
    Object? targetReps = _keep,
    Object? bands = _keep,
    Object? weightUnit = _keep,
    Object? loadCount = _keep,
    bool? isWarmup,
    Object? completedAt = _keep,
  }) => WorkoutSet(
    id: id,
    index: index ?? this.index,
    authorId: authorId,
    reps: identical(reps, _keep) ? this.reps : reps as int?,
    weightKg: identical(weightKg, _keep)
        ? this.weightKg
        : (weightKg as num?)?.toDouble(),
    durationSec: identical(durationSec, _keep)
        ? this.durationSec
        : durationSec as int?,
    distanceMeters: identical(distanceMeters, _keep)
        ? this.distanceMeters
        : (distanceMeters as num?)?.toDouble(),
    rpe: identical(rpe, _keep) ? this.rpe : (rpe as num?)?.toDouble(),
    side: identical(side, _keep) ? this.side : side as SetSide?,
    kind: kind ?? this.kind,
    parentSetId: parentSetId,
    targetReps: identical(targetReps, _keep)
        ? this.targetReps
        : targetReps as int?,
    bands: identical(bands, _keep) ? this.bands : bands as List<String>?,
    weightUnit: identical(weightUnit, _keep)
        ? this.weightUnit
        : weightUnit as WeightUnit?,
    loadCount: identical(loadCount, _keep) ? this.loadCount : loadCount as int?,
    machineBaseKg: machineBaseKg,
    isWarmup: isWarmup ?? this.isWarmup,
    completedAt: identical(completedAt, _keep)
        ? this.completedAt
        : completedAt as DateTime?,
  );

  @override
  List<Object?> get props => [
    id,
    index,
    authorId,
    reps,
    weightKg,
    durationSec,
    distanceMeters,
    rpe,
    side,
    kind,
    parentSetId,
    targetReps,
    bands,
    weightUnit,
    loadCount,
    machineBaseKg,
    isWarmup,
    completedAt,
  ];
}

/// A template's target for one set (`SetTarget.swift`), the fields the rules
/// read.
class const SetTarget({
  final int setNumber = 1,
  final int? minReps,
  final int? maxReps,
  final int? rirTarget,
  final SetTargetSetType setType = SetTargetSetType.standard,
  final int? amrapTargetReps,
}) extends Equatable {
  /// The range a set with neither end is progressed through.
  static const defaultRepRangeMin = 8;
  static const defaultRepRangeMax = 12;

  /// How far a range with one end set reaches to the other.
  static const defaultRangeWidth = 4;

  /// Its own reps-in-reserve target, else none for an AMRAP or failure set.
  int? get effectiveRirTarget =>
      rirTarget ??
      (setType == SetTargetSetType.amrap || setType == SetTargetSetType.failure
          ? 0
          : null);

  @override
  List<Object?> get props => [
    setNumber,
    minReps,
    maxReps,
    rirTarget,
    setType,
    amrapTargetReps,
  ];
}

/// One piece of equipment a variation uses (`EquipmentRef`).
class const EquipmentRef(final EquipmentKind kind, final String equipmentId);

/// What kind of equipment an [EquipmentRef] names.
enum EquipmentKind {
  loadableBar,
  plateLoadedMachine,
  cableMachine,
  pinLoadedMachine,
  freeWeight,
  fixedWeightBar,
  bodyWeight,
  bands,
  supportEquipment,
  accessoryEquipment,
  loadableAccessoryEquipment,
}

/// The kind of load `refs` lift (`LoadKind`), as a key: a bar or plate machine
/// first, then a stack, a free weight (by id), a fixed bar, body weight and
/// bands. `null` for none of them.
String? loadKind(List<EquipmentRef> refs) {
  bool has(EquipmentKind kind) => refs.any((ref) => ref.kind == kind);
  final freeWeights = refs.where((ref) => ref.kind == EquipmentKind.freeWeight);
  if (has(EquipmentKind.loadableBar)) return 'barAndPlates';
  if (has(EquipmentKind.plateLoadedMachine)) return 'plateMachine';
  if (has(EquipmentKind.cableMachine) || has(EquipmentKind.pinLoadedMachine)) {
    return 'stack';
  }
  if (freeWeights.isNotEmpty) {
    final weight = freeWeights
        .where((ref) => !ref.equipmentId.endsWith('plates'))
        .followedBy(freeWeights)
        .first;
    return 'freeWeight:${weight.equipmentId}';
  }
  if (has(EquipmentKind.fixedWeightBar)) return 'fixedBar';
  if (has(EquipmentKind.bodyWeight)) return 'bodyweight';
  if (has(EquipmentKind.bands)) return 'bands';
  return null;
}

/// Whether two variations lift the same kind of load; either side unknown
/// matches (`WorkoutSessionModel.isSameLoad`).
bool isSameLoad(List<EquipmentRef>? lhs, List<EquipmentRef>? rhs) {
  final left = lhs == null ? null : loadKind(lhs);
  final right = rhs == null ? null : loadKind(rhs);
  return left == null || right == null || left == right;
}

/// One exercise in a session (`WorkoutExerciseModel`).
class const WorkoutExercise({
  required final String id,
  final String? templateId,
  final String name = '',
  final TrackingMode trackingMode = TrackingMode.weightReps,
  final int index = 0,
  final String? imageName,
  final List<WorkoutSet> sets = const [],
  final List<SetTarget> setTargets = const [],
  final String? supersetGroupId,
  final int? restSeconds,
  final WeightUnit? weightUnit,
  final int? loadsPerSet,

  /// The active variation's equipment.
  final List<EquipmentRef>? resistanceEquipment,
}) extends Equatable {
  /// The template it came from; [id] when none was given.
  String get template => templateId ?? id;

  /// The sets that count as work.
  List<WorkoutSet> get workingSets =>
      sets.where((set) => !set.isWarmup).toList();

  /// The working sets that were done.
  List<WorkoutSet> get loggedWorkingSets =>
      sets.where((set) => !set.isWarmup && set.completedAt != null).toList();

  /// Worked one limb at a time, read off its rows.
  bool get isPerSide => sets.any((set) => !set.isWarmup && set.side != null);

  /// The sides logged apart, a left and a right row per set.
  bool get isSplit => sets.any(
    (set) =>
        !set.isWarmup &&
        (set.side == SetSide.left || set.side == SetSide.right),
  );

  /// The rows one more set is made of.
  List<SetSide?> get sidesPerSet => isSplit
      ? [SetSide.left, SetSide.right]
      : isPerSide
      ? [SetSide.both]
      : [null];

  /// Working sets asked for, pairs counted once.
  int get workingSetCount => pairedSetCount(workingSets);

  /// Working sets logged, a pair counting from either limb.
  int get loggedSetCount => pairedSetCount(loggedWorkingSets);

  /// The number [set] is shown as: 1L, 1R, 2L… share their number.
  int workingSetNumber(WorkoutSet set) {
    final upTo = <WorkoutSet>[];
    for (final candidate in workingSets) {
      upTo.add(candidate);
      if (candidate.id == set.id) break;
    }
    return pairedSetCount(upTo);
  }

  /// This exercise's row for [set] (a row of [current]) as logged last time:
  /// a warm-up by its place among the warm-ups, a working set by its number,
  /// then its side.
  WorkoutSet? matchingSet(WorkoutSet set, WorkoutExercise current) {
    if (set.isWarmup) {
      final today = current.sets
          .where((s) => s.isWarmup && s.side == set.side)
          .toList();
      final last = sets.where((s) => s.isWarmup && s.side == set.side).toList();
      final ordinal = today.indexWhere((s) => s.id == set.id);
      return ordinal < 0 || ordinal >= last.length ? null : last[ordinal];
    }
    final number = current.workingSetNumber(set);
    final candidates = workingSets
        .where((s) => workingSetNumber(s) == number)
        .toList();
    for (final side in acceptableSides(set.side)) {
      for (final match in candidates) {
        if (match.side == side) return match;
      }
    }
    return null;
  }

  /// [set] stamped as it is logged with the unit and how many were lifted.
  WorkoutSet stamping(WorkoutSet set) => set.copyWith(
    weightUnit: set.weightUnit ?? weightUnit,
    loadCount: set.loadCount ?? loadsPerSet,
  );

  WorkoutExercise copyWith({List<WorkoutSet>? sets}) => WorkoutExercise(
    id: id,
    templateId: templateId,
    name: name,
    trackingMode: trackingMode,
    index: index,
    imageName: imageName,
    sets: sets ?? this.sets,
    setTargets: setTargets,
    supersetGroupId: supersetGroupId,
    restSeconds: restSeconds,
    weightUnit: weightUnit,
    loadsPerSet: loadsPerSet,
    resistanceEquipment: resistanceEquipment,
  );

  @override
  List<Object?> get props => [
    id,
    templateId,
    name,
    trackingMode,
    index,
    imageName,
    sets,
    setTargets,
    supersetGroupId,
    restSeconds,
    weightUnit,
    loadsPerSet,
    resistanceEquipment,
  ];
}

/// The sides a row takes last time's figures from, in order: a limb its own
/// side, then a row for both; a row for both takes the left.
List<SetSide?> acceptableSides(SetSide? side) => switch (side) {
  SetSide.left || SetSide.right => [side, SetSide.both, null],
  SetSide.both || null => [SetSide.both, null, SetSide.left],
};

/// One session (`WorkoutSessionModel`).
class const WorkoutSession({
  required final List<WorkoutExercise> exercises,
  final bool? isDeload,
}) extends Equatable {
  List<WorkoutExercise> _matching(String templateId) =>
      exercises.where((e) => e.template == templateId).toList()
        ..sort((a, b) => a.index.compareTo(b.index));

  /// Which appearance of its exercise [exercise] is, from 0, in index order.
  int occurrence(WorkoutExercise exercise) {
    final index = _matching(exercise.template)
        .indexWhere((e) => e.id == exercise.id);
    return index < 0 ? 0 : index;
  }

  /// The [occurrence]th appearance of [templateId], from 0.
  WorkoutExercise? exercise(String templateId, int occurrence) {
    final matches = _matching(templateId);
    return occurrence >= 0 && occurrence < matches.length
        ? matches[occurrence]
        : null;
  }

  @override
  List<Object?> get props => [exercises, isDeload];
}

// MARK: - Pairing (`WorkoutSetPairing.swift`)

/// How many sets these rows amount to: a right row straight after a left one
/// folds into it, and a sub-set adds nothing.
int pairedSetCount(Iterable<WorkoutSet> sets) {
  var count = 0;
  SetSide? previousSide;
  for (final set in sets) {
    if (set.isSubSet) continue;
    if (!(set.side == SetSide.right && previousSide == SetSide.left)) count++;
    previousSide = set.side;
  }
  return count;
}

/// Sets fully done, a pair counting once both halves are.
int fullyCompletedPairedSetCount(List<WorkoutSet> sets) => pairedSetCount(
  sets.where((row) {
    if (row.completedAt == null) return false;
    final pair = pairedSetIds(sets, row.id);
    if (pair.length != 2) return true;
    final partnerId = pair.firstWhere((id) => id != row.id);
    return sets.firstWhere((s) => s.id == partnerId).completedAt != null;
  }),
);

/// The ids of the rows making up the same set as [setId]: itself, and the
/// opposite side when it is half of a pair.
List<String> pairedSetIds(List<WorkoutSet> sets, String setId) {
  final position = sets.indexWhere((s) => s.id == setId);
  if (position < 0) return [];
  final set = sets[position];
  if (set.side == SetSide.left &&
      position + 1 < sets.length &&
      sets[position + 1].side == SetSide.right &&
      !sets[position + 1].isWarmup) {
    return [set.id, sets[position + 1].id];
  }
  if (set.side == SetSide.right &&
      position > 0 &&
      sets[position - 1].side == SetSide.left &&
      !sets[position - 1].isWarmup) {
    return [sets[position - 1].id, set.id];
  }
  return [set.id];
}

List<WorkoutSet> _reindexed(List<WorkoutSet> sets) => [
  for (final (position, set) in sets.indexed) set.copyWith(index: position + 1),
];

/// Each `both` row as a left and a right row, figures and tick copied; the
/// left keeps the row's id and the right takes [newId]'s.
List<WorkoutSet> splittingSides(
  List<WorkoutSet> sets,
  String Function() newId,
) => _reindexed([
  for (final set in sets)
    if (set.side != SetSide.both)
      set
    else ...[
      set.copyWith(side: SetSide.left),
      WorkoutSet(
        id: newId(),
        authorId: set.authorId,
        index: set.index,
        reps: set.reps,
        weightKg: set.weightKg,
        durationSec: set.durationSec,
        distanceMeters: set.distanceMeters,
        rpe: set.rpe,
        side: SetSide.right,
        kind: set.kind,
        parentSetId: set.parentSetId,
        bands: set.bands,
        isWarmup: set.isWarmup,
        completedAt: set.completedAt,
      ),
    ],
]);

/// Each left/right pair as one `both` row with the left's figures, ticked
/// only when both sides were.
List<WorkoutSet> joiningSides(List<WorkoutSet> sets) {
  final joined = <WorkoutSet>[];
  for (final set in sets) {
    final left = joined.isEmpty ? null : joined.last;
    if (set.side == SetSide.right &&
        left != null &&
        left.side == SetSide.left &&
        !left.isWarmup &&
        !set.isWarmup) {
      joined.last = left.copyWith(
        side: SetSide.both,
        completedAt: set.completedAt == null ? null : left.completedAt,
      );
      continue;
    }
    joined.add(set);
  }
  return _reindexed([
    for (final set in joined)
      if (set.side == SetSide.left || set.side == SetSide.right)
        set.copyWith(side: SetSide.both)
      else
        set,
  ]);
}

/// The settings the rules read (`WorkoutSettings.swift`), with its defaults.
class const WorkoutSettings({
  final bool supersetAutoScroll = true,
  final bool exerciseAutoNext = true,
  final bool useRestTimers = true,
  final bool restAfterLastWarmUp = true,
  final bool restBetweenExercises = true,
  final bool restBetweenSideSets = false,
  final int? supersetTransitionRestSeconds,
  final int? intraSetRestSeconds,
  final int? intraSetRestMyoSeconds,
  final int? intraSetRestPauseSeconds,
  final int? intraSetRestClusterSeconds,
  final double warmUpRestScaling = 0.75,
  final double betweenExercisesRestScaling = 1.0,
  final double sideSetRestScaling = 0.5,
  final Map<ExerciseType, int> restDurationsByExerciseType = const {},
  final int defaultRestDurationSeconds = 90,
  final bool? setPlanning,
  final bool? amrapRaisesTarget,
  final int? amrapAddsWeightAtTarget,
  final bool? amrapAddsWeight,
}) {
  /// What builds before `amrapAddsWeight` stored to mean "never" (`Int.max`).
  static const legacyNeverAddsWeight = 0x7FFFFFFFFFFFFFFF;

  bool get plansSets => setPlanning ?? false;

  bool get raisesAmrapTarget => amrapRaisesTarget ?? true;

  int get amrapWeightCeiling => amrapAddsWeightAtTarget == legacyNeverAddsWeight
      ? 12
      : amrapAddsWeightAtTarget ?? 12;

  bool get addsWeightAtAmrapTarget =>
      amrapAddsWeight ?? (amrapAddsWeightAtTarget != legacyNeverAddsWeight);

  /// The breath within a set of [kind]; `null` for a kind that takes none.
  int? intraSetRest(SetKind kind) => switch (kind) {
    SetKind.myo => intraSetRestMyoSeconds ?? intraSetRestSeconds ?? 15,
    SetKind.restPause => intraSetRestPauseSeconds ?? intraSetRestSeconds ?? 20,
    SetKind.cluster => intraSetRestClusterSeconds ?? intraSetRestSeconds ?? 15,
    _ => null,
  };
}
