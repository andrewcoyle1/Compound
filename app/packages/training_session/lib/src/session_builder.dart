/// Building a session: from a template, prefilled (`WorkoutSessionModel`'s
/// template initializer, `WorkingSetPrefill`, `applyingSetPlan`, the warm-up
/// ramp), empty, and the exercises a session gains or swaps part-way
/// through (`defaultSets`, `addingSet`, `WorkoutTrackerPresenter.swapping`).
library;

import 'dart:math' as math;

import 'package:compound_models/compound_models.dart' as m;
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/src/library_exercise.dart';
import 'package:training_session/src/mapping.dart';
import 'package:training_session/src/model_copies.dart';
import 'package:training_session/src/session_load.dart';
import 'package:training_session/src/weight_stepper.dart';

/// Makes a new id.
typedef IdGenerator = String Function();

final _random = math.Random.secure();

/// A random (version 4) UUID in Swift's `UUID().uuidString` form: upper
/// case, hyphenated.
String newUuid() {
  final bytes = [for (var i = 0; i < 16; i++) _random.nextInt(256)];
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')]
      .join()
      .toUpperCase();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// The template's targets for [microcycle] (1-based): the latest override
/// starting at or before it, else the base targets
/// (`WorkoutTemplateExercise.setTargets(forMicrocycle:)`).
List<m.SetTarget> setTargetsForMicrocycle(
  m.WorkoutTemplateExercise exercise,
  int? microcycle,
) {
  if (microcycle == null || microcycle < 1) return exercise.setTargets;
  m.MicrocycleSetTargets? latest;
  for (final targets in exercise.setTargetsByMicrocycle) {
    if (targets.fromMicrocycle > microcycle) continue;
    if (latest == null || latest.fromMicrocycle < targets.fromMicrocycle) {
      latest = targets;
    }
  }
  return latest?.setTargets ?? exercise.setTargets;
}

/// [exercise] with the given parts replaced; `WorkoutTemplateExercise` has
/// no copy of its own.
m.WorkoutTemplateExercise _templateExercise(
  m.WorkoutTemplateExercise exercise, {
  m.ExerciseModel? library,
  List<m.SetTarget>? setTargets,
}) => m.WorkoutTemplateExercise(
  id: exercise.id,
  exercise: library ?? exercise.exercise,
  setTargets: setTargets ?? exercise.setTargets,
  setRestTimers: exercise.setRestTimers,
  notes: exercise.notes,
  warmupSetCount: exercise.warmupSetCount,
  restSeconds: exercise.restSeconds,
  substituteExerciseIds: exercise.substituteExerciseIds,
  supersetGroupId: exercise.supersetGroupId,
  linkUrl: exercise.linkUrl,
  setTargetsByMicrocycle: exercise.setTargetsByMicrocycle,
);

m.WorkoutTemplateModel _withExercises(
  m.WorkoutTemplateModel template,
  List<m.WorkoutTemplateExercise> exercises,
) => m.WorkoutTemplateModel(
  workoutId: template.workoutId,
  authorId: template.authorId,
  name: template.name,
  dateCreated: template.dateCreated,
  dateModified: template.dateModified,
  exercises: exercises,
  description: template.description,
  gymProfileId: template.gymProfileId,
  imageUrl: template.imageUrl,
);

/// The empty sets an exercise starts with, [targetCount] of them (at least
/// one): every figure empty, a `both` row each for an exercise worked a side
/// at a time, each set the kind its target asks for, starting at the effort
/// it aims for (`WorkoutSessionModel.defaultSets`).
List<m.WorkoutSetModel> defaultSets({
  required String authorId,
  required DateTime now,
  required IdGenerator newId,
  int targetCount = 3,
  bool perSide = false,
  List<m.SetTarget> setTargets = const [],
}) => [
  for (var index = 1; index <= math.max(targetCount, 1); index++)
    m.WorkoutSetModel(
      id: newId(),
      authorId: authorId,
      index: index,
      isWarmup: false,
      dateCreated: now,
      rpe: index <= setTargets.length
          ? switch (rulesTarget(setTargets[index - 1]).effectiveRirTarget) {
              final rir? => r.EffortScale.rpeFromRir(rir),
              null => null,
            }
          : null,
      sideRawValue: perSide ? m.SetSide.both.value : null,
      kindRawValue: index <= setTargets.length
          ? switch (r.SetKind.fromSetType(
              setTargets[index - 1].setType.rules,
            )) {
              r.SetKind.standard => null,
              final kind => kind.model.value,
            }
          : null,
    ),
];

/// The template's set plan laid on working sets already built and
/// prefilled: drops stepping down from the set, mini-sets at its weight,
/// an AMRAP set's target, and partials, a stretch or a hold after it
/// (`WorkoutSessionModel.applyingSetPlan`).
List<m.WorkoutSetModel> applyingSetPlan(
  List<m.WorkoutSetModel> workingSets, {
  required List<m.SetTarget> setTargets,
  required String authorId,
  required DateTime now,
  required IdGenerator newId,
  r.WeightRoundingRule? rounding,
}) => [
  for (final (position, set) in workingSets.indexed)
    if (position >= setTargets.length || set.parentSetId != null)
      set
    else
      ..._planned(
        set,
        setTargets[position],
        authorId: authorId,
        now: now,
        newId: newId,
        rounding: rounding,
      ),
];

List<m.WorkoutSetModel> _planned(
  m.WorkoutSetModel set,
  m.SetTarget target, {
  required String authorId,
  required DateTime now,
  required IdGenerator newId,
  required r.WeightRoundingRule? rounding,
}) {
  m.WorkoutSetModel piece(
    m.SetKind kind, {
    double? weightKg,
    int? reps,
    int? durationSec,
  }) => m.WorkoutSetModel(
    id: newId(),
    authorId: authorId,
    index: set.index,
    isWarmup: false,
    dateCreated: now,
    reps: reps,
    weightKg: weightKg,
    durationSec: durationSec,
    sideRawValue: set.side?.value,
    kindRawValue: kind == m.SetKind.standard ? null : kind.value,
    parentSetId: set.id,
  );
  switch (target.setType) {
    case m.SetTargetSetType.standard:
      return [set];
    case m.SetTargetSetType.failure || m.SetTargetSetType.amrap:
      return [
        set.copyWith(targetReps: set.targetReps ?? target.amrapTargetReps),
      ];
    case m.SetTargetSetType.drop:
      var weight = set.weightKg;
      return [
        set,
        for (var i = 0; i < math.max(target.dropCount ?? 0, 0); i++)
          piece(
            m.SetKind.drop,
            weightKg: weight = r.ActiveWorkout.plannedDropWeightKg(
              weight,
              target.dropStepPercent ?? 20,
              rounding,
            ),
            reps: target.dropReps,
          ),
      ];
    case m.SetTargetSetType.myo ||
        m.SetTargetSetType.restPause ||
        m.SetTargetSetType.cluster:
      return [
        set,
        for (var i = 0; i < math.max(target.miniSetCount ?? 0, 0); i++)
          piece(m.SetKind.standard, weightKg: set.weightKg),
      ];
    case m.SetTargetSetType.partials:
      return [
        set,
        piece(
          m.SetKind.partials,
          weightKg: set.weightKg,
          reps: target.partialReps,
        ),
      ];
    case m.SetTargetSetType.stretch:
      return [set, piece(m.SetKind.stretch, durationSec: target.holdSeconds)];
    case m.SetTargetSetType.hold:
      return [
        set,
        piece(
          m.SetKind.hold,
          weightKg: set.weightKg,
          durationSec: target.holdSeconds,
        ),
      ];
  }
}

/// The working weight and reps last time: the first working set's, else
/// the last set's (`estimateWorkingWeightFromPrevious`).
(double?, int?) _estimate(List<m.WorkoutSetModel>? previous) {
  if (previous == null) return (null, null);
  final set =
      previous.where((set) => !set.isWarmup).firstOrNull ?? previous.lastOrNull;
  return (set?.weightKg, set?.reps);
}

/// The session starting [template] begins (`WorkoutSessionModel(template:)`):
/// each exercise on the equipment it starts on, its working sets filled as
/// [prefill] asks, the set plan laid on when [plansSets], and warm-ups
/// before them. [previousSession] is the last session of this template.
m.WorkoutSessionModel sessionFromTemplate({
  required String authorId,
  required m.WorkoutTemplateModel template,
  required DateTime now,
  IdGenerator newId = newUuid,
  String? id,
  String? notes,
  String? mesocycleId,
  int? microcycleIndex,
  m.WorkoutSessionModel? previousSession,
  m.GymProfileModel? gym,
  Map<String, UnitPreference> unitPreferences = const {},
  r.SessionPrefill prefill = const r.PrefillPreviousValues(),
  bool plansSets = false,
}) {
  final exercises = <m.WorkoutExerciseModel>[];
  for (final (idx, templateExercise) in template.exercises.indexed) {
    final exercise = templateExercise.exercise;
    final mode = exercise.trackingMode;
    final setTargets = setTargetsForMicrocycle(
      templateExercise,
      microcycleIndex,
    );
    final occurrence = template.exercises
        .take(idx)
        .where((e) => e.exercise.id == exercise.id)
        .length;
    final last = previousSession?.exercise(exercise.id, occurrence);
    final variations = exercise.equipmentVariations;
    final chosen = SessionLoadChoice.variationId(
      variations: variations,
      previous: last,
      previousGymId: previousSession?.gymProfileId,
      gym: gym,
    );
    final refs = variations
        .where((variation) => variation.id == chosen)
        .firstOrNull
        ?.resistanceEquipment;
    final weightUnit = SessionLoadChoice.weightUnit(
      preference: unitPreferences[exercise.id],
      refs: refs,
      gym: gym,
    );
    // Last time speaks for this time only on the same kind of load.
    final previousSets =
        last != null &&
            sameLoad(last.activeVariation?.resistanceEquipment, refs)
        ? last.sets
        : null;
    final (estimatedWeight, estimatedReps) = _estimate(previousSets);
    final rule = weightRoundingRule(
      exercise: exercise,
      gym: gym,
      preferredUnit: weightUnit,
      resistanceEquipment: refs,
    );

    var workingSets = defaultSets(
      authorId: authorId,
      now: now,
      newId: newId,
      targetCount: math.max(setTargets.length, 1),
      perSide: exercise.isPerSide,
      setTargets: setTargets,
    );
    workingSets = modelSets(
      r.prefillWorkingSets(
        workingSets.map(rulesSet).toList(),
        prefill: prefill,
        templateId: exercise.id,
        previousSets: previousSets?.map(rulesSet).toList(),
        round: rule.round,
        occurrence: occurrence,
      ),
      originals: workingSets,
      now: now,
    );
    if (plansSets) {
      // In some unit, so a drop off an unconstrained weight still lands on a
      // half kilo.
      workingSets = applyingSetPlan(
        workingSets,
        setTargets: setTargets,
        authorId: authorId,
        now: now,
        newId: newId,
        rounding: weightRoundingRule(
          exercise: exercise,
          gym: gym,
          preferredUnit: weightUnit ?? m.ExerciseWeightUnit.kilograms,
          resistanceEquipment: refs,
        ),
      );
    }

    final first = workingSets.firstOrNull;
    final warmUps = modelSets(
      r.WarmUps.generate(
        trackingMode: mode.rules,
        workingWeightKg: first?.weightKg ?? estimatedWeight,
        workingReps: first?.reps ?? estimatedReps,
        setTargets: setTargets.map(rulesTarget).toList(),
        newId: newId,
        authorId: authorId,
        exerciseType: exercise.type?.rules,
        round: rule.round,
        count: templateExercise.warmupSetCount,
      ),
      originals: const [],
      now: now,
    );

    exercises.add(
      stampingMachineBase(
        m.WorkoutExerciseModel(
          id: newId(),
          authorId: authorId,
          templateId: exercise.id,
          name: exercise.name,
          trackingMode: mode,
          index: idx + 1,
          imageName: exercise.sessionImageName,
          sets: [
            for (final (position, set) in [...warmUps, ...workingSets].indexed)
              set.copyWith(index: position + 1),
          ],
          setTargets: setTargets,
          chosenVariationId: chosen,
          equipmentVariations: variations,
          supersetGroupId: templateExercise.supersetGroupId,
          planNotes: templateExercise.notes,
          planSlotId: templateExercise.id,
          restSeconds: templateExercise.restSeconds,
          linkUrl: templateExercise.linkUrl,
          substituteExerciseIds: templateExercise.substituteExerciseIds,
          weightUnit: weightUnit,
          loadsPerSet: SessionLoadChoice.loadsPerSet(exercise),
          machineBaseKg: SessionLoadChoice.machineBaseKg(refs: refs, gym: gym),
        ),
      ),
    );
  }
  return m.WorkoutSessionModel(
    id: id ?? newId(),
    authorId: authorId,
    name: template.name,
    workoutTemplateId: template.workoutId,
    mesocycleId: mesocycleId,
    dateCreated: now,
    dateModified: now,
    notes: notes,
    exercises: exercises,
    gymProfileId: gym?.id,
  );
}

/// A session with no template and no exercises, which the tracker adds to
/// as it goes (`startBlankWorkout`). Swift names it "Workout", in English.
m.WorkoutSessionModel emptySession({
  required String authorId,
  required DateTime now,
  IdGenerator newId = newUuid,
  String name = 'Workout',
}) => m.WorkoutSessionModel(
  id: newId(),
  authorId: authorId,
  name: name,
  dateCreated: now,
  dateModified: now,
  exercises: const [],
);

/// One more set, two rows when the sides are split, each carrying the last
/// figures on its side, indexed past the highest (`addingSet`).
m.WorkoutExerciseModel addingSet(
  m.WorkoutExerciseModel exercise, {
  required String authorId,
  required DateTime now,
  IdGenerator newId = newUuid,
}) {
  var nextIndex = exercise.sets.map((set) => set.index).fold(0, math.max) + 1;
  final own = exercise.sets.where((set) => set.parentSetId == null).toList();
  final added = <m.WorkoutSetModel>[];
  for (final side in rulesExercise(exercise).sidesPerSet) {
    final sideModel = side?.model;
    final last =
        own.where((set) => side == null || set.side == sideModel).lastOrNull ??
        own.lastOrNull;
    added.add(
      m.WorkoutSetModel(
        id: newId(),
        authorId: authorId,
        index: nextIndex++,
        isWarmup: false,
        dateCreated: now,
        reps: last?.reps,
        weightKg: last?.weightKg,
        durationSec: last?.durationSec,
        distanceMeters: last?.distanceMeters,
        rpe: last?.rpe,
        sideRawValue: sideModel?.value,
        bands: last?.bands,
      ),
    );
  }
  return exercise.copyWith(sets: [...exercise.sets, ...added]);
}

/// A library exercise as it joins a session part-way through, on the
/// equipment the session chooses in [gym] (`addSelectedExercises`).
m.WorkoutExerciseModel addedExercise(
  m.WorkoutTemplateExercise template, {
  required String authorId,
  required int index,
  required DateTime now,
  required m.GymProfileModel? gym,
  required UnitPreference? preference,
  IdGenerator newId = newUuid,
}) {
  final exercise = template.exercise;
  return takingLoad(
    m.WorkoutExerciseModel(
      id: newId(),
      authorId: authorId,
      templateId: exercise.id,
      name: exercise.name,
      trackingMode: exercise.trackingMode,
      index: index,
      imageName: exercise.sessionImageName,
      sets: defaultSets(
        authorId: authorId,
        now: now,
        newId: newId,
        targetCount: math.max(template.setTargets.length, 1),
        perSide: exercise.isPerSide,
        setTargets: template.setTargets,
      ),
      setTargets: template.setTargets,
    ),
    exercise: exercise,
    gym: gym,
    preference: preference,
  );
}

/// [old] swapped for [replacement] (`WorkoutTrackerPresenter.swapping`):
/// `kept` is [old] with only its logged sets, out of any superset, or
/// `null` when nothing was logged and the replacement takes its place and
/// id. The replacement has the open working sets (three when none), their
/// targets renumbered from one, and the slot's plan.
({m.WorkoutExerciseModel? kept, m.WorkoutExerciseModel replacement}) swapping(
  m.WorkoutExerciseModel old, {
  required m.ExerciseModel replacement,
  required String authorId,
  required DateTime now,
  IdGenerator newId = newUuid,
}) {
  final logged = old.sets.where((set) => set.completedAt != null).toList();
  final rulesOld = rulesExercise(old);
  final openCount = r.pairedSetCount(
    rulesOld.sets.where((set) => set.completedAt == null && !set.isWarmup),
  );
  final perSide = replacement.isPerSide;
  var sets = defaultSets(
    authorId: authorId,
    now: now,
    newId: newId,
    targetCount: openCount > 0 ? openCount : 3,
    perSide: perSide,
  );
  if (perSide && rulesOld.isSplit) {
    sets = modelSets(
      r.splittingSides(sets.map(rulesSet).toList(), newId),
      originals: sets,
      now: now,
    );
  }
  final loggedCount = rulesOld.loggedSetCount;
  var targets = [
    for (final target in old.setTargets)
      if (target.setNumber > loggedCount)
        m.SetTarget(
          id: target.id,
          setNumber: target.setNumber - loggedCount,
          minReps: target.minReps,
          maxReps: target.maxReps,
          rirTarget: target.rirTarget,
          setType: target.setType,
          dropCount: target.dropCount,
          dropStepPercent: target.dropStepPercent,
          dropReps: target.dropReps,
          miniSetCount: target.miniSetCount,
          amrapTargetReps: target.amrapTargetReps,
          partialReps: target.partialReps,
          holdSeconds: target.holdSeconds,
        ),
  ];
  if (targets.isEmpty) {
    targets = [
      m.SetTarget(
        id: newId(),
        setNumber: 1,
        minReps: r.SetTarget.defaultRepRangeMin,
        maxReps: r.SetTarget.defaultRepRangeMax,
      ),
    ];
  }
  final fresh = m.WorkoutExerciseModel(
    id: logged.isEmpty ? old.id : newId(),
    authorId: authorId,
    templateId: replacement.id,
    name: replacement.name,
    trackingMode: replacement.trackingMode,
    index: old.index + (logged.isEmpty ? 0 : 1),
    imageName: replacement.sessionImageName,
    sets: sets,
    setTargets: targets,
    equipmentVariations: replacement.equipmentVariations,
    supersetGroupId: old.supersetGroupId,
    planNotes: old.planNotes,
    planSlotId: old.planSlotId,
    restSeconds: old.restSeconds,
    linkUrl: old.linkUrl,
    substituteExerciseIds: old.substituteExerciseIds,
  );
  if (logged.isEmpty) return (kept: null, replacement: fresh);
  return (
    kept: old.copyWith(sets: logged, supersetGroupId: null),
    replacement: fresh,
  );
}

/// Whether [replacement] is measured as [old] is, the same tracking mode and
/// worked a side at a time or not, so [old]'s logged sets can move to it
/// (`ExerciseTrackerPresenter.onSwapPressed`'s `measuredAlike`).
bool measuresAlike(m.WorkoutExerciseModel old, m.ExerciseModel replacement) =>
    old.trackingMode == replacement.trackingMode &&
    rulesExercise(old).isPerSide == replacement.isPerSide;

/// [old] swapped in place for [replacement], as a finished workout is
/// corrected (`ExerciseTrackerPresenter.swap(_:to:keepingLoggedSets:)`).
/// With [keepLoggedSets] the logged sets stay, followed by as many fresh
/// working sets as were open (an open warm-up is not one); with nothing
/// kept, three. The sets are numbered from one, kept split when [old] was
/// and something was kept, the targets start over at the standard one, and
/// the replacement is put on the equipment the session chooses in [gym].
/// Its id, place, superset and notes stay.
m.WorkoutExerciseModel swappingInPlace(
  m.WorkoutExerciseModel old, {
  required m.ExerciseModel replacement,
  required bool keepLoggedSets,
  required String authorId,
  required DateTime now,
  required m.GymProfileModel? gym,
  required UnitPreference? preference,
  IdGenerator newId = newUuid,
}) {
  final logged = keepLoggedSets
      ? old.sets.where((set) => set.completedAt != null).toList()
      : <m.WorkoutSetModel>[];
  final rulesOld = rulesExercise(old);
  final openCount = r.pairedSetCount(
    rulesOld.sets.where((set) => set.completedAt == null && !set.isWarmup),
  );
  final fresh = logged.isEmpty || openCount > 0
      ? defaultSets(
          authorId: authorId,
          now: now,
          newId: newId,
          targetCount: logged.isEmpty ? 3 : openCount,
          perSide: replacement.isPerSide,
        )
      : <m.WorkoutSetModel>[];
  var sets = [
    for (final (index, set) in [...logged, ...fresh].indexed)
      set.copyWith(index: index + 1),
  ];
  // Kept split if it was, so the fresh rows match the logged pairs above.
  if (rulesOld.isSplit && logged.isNotEmpty) {
    sets = modelSets(
      r.splittingSides(sets.map(rulesSet).toList(), newId),
      originals: sets,
      now: now,
    );
  }
  return takingLoad(
    old.copyWith(
      templateId: replacement.id,
      name: replacement.name,
      trackingMode: replacement.trackingMode,
      imageName: replacement.sessionImageName,
      sets: sets,
      setTargets: [
        m.SetTarget(
          id: newId(),
          setNumber: 1,
          minReps: r.SetTarget.defaultRepRangeMin,
          maxReps: r.SetTarget.defaultRepRangeMax,
        ),
      ],
    ),
    exercise: replacement,
    gym: gym,
    preference: preference,
  );
}

/// Each template exercise with the library's current copy of it: a
/// template keeps the copy taken when it was built, so equipment corrected
/// since would never reach it.
m.WorkoutTemplateModel withLibraryExercises(
  m.WorkoutTemplateModel template,
  List<m.ExerciseModel> library,
) => _withExercises(template, [
  for (final exercise in template.exercises)
    _templateExercise(
      exercise,
      library: library
          .where((candidate) => candidate.id == exercise.exercise.id)
          .firstOrNull,
    ),
]);

/// [template] with each exercise's targets for [microcycle], as the planner
/// reads them.
m.WorkoutTemplateModel weekOf(
  m.WorkoutTemplateModel template,
  int? microcycle,
) => _withExercises(template, [
  for (final exercise in template.exercises)
    _templateExercise(
      exercise,
      setTargets: setTargetsForMicrocycle(exercise, microcycle),
    ),
]);
