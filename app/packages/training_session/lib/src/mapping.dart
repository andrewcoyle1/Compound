/// `compound_models`, which mirror Firestore, onto `training_rules`' value
/// types and back.
///
/// Going there keeps every field the rules read. Coming back, a set is
/// matched to the stored one it came from by id, so what the rules never see
/// (a set's `date_created`, a raw value this build does not know) survives a
/// round trip; a set the rules made (a drop, a split side) is new.
library;

import 'package:compound_models/compound_models.dart' as m;
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/src/model_copies.dart';

extension TrackingModeRules on m.TrackingMode {
  r.TrackingMode get rules => r.TrackingMode.values.byName(name);
}

extension SetSideRules on m.SetSide {
  r.SetSide get rules => r.SetSide.values.byName(name);
}

extension SetKindRules on m.SetKind {
  r.SetKind get rules => r.SetKind.values.byName(name);
}

extension WeightUnitRules on m.ExerciseWeightUnit {
  r.WeightUnit get rules => r.WeightUnit.values.byName(name);
}

extension ExerciseTypeRules on m.ExerciseType {
  r.ExerciseType get rules => r.ExerciseType.values.byName(name);
}

extension SetTargetSetTypeRules on m.SetTargetSetType {
  r.SetTargetSetType get rules => r.SetTargetSetType.values.byName(name);
}

extension AdjustmentModeRules on m.ProgressionAdjustmentMode {
  r.ProgressionAdjustmentMode get rules =>
      r.ProgressionAdjustmentMode.values.byName(name);
}

extension RulesSetSideModel on r.SetSide {
  m.SetSide get model => m.SetSide.values.byName(name);
}

extension RulesSetKindModel on r.SetKind {
  m.SetKind get model => m.SetKind.values.byName(name);
}

extension RulesWeightUnitModel on r.WeightUnit {
  m.ExerciseWeightUnit get model => m.ExerciseWeightUnit.values.byName(name);
}

/// The rules' copy of a reference to equipment.
r.EquipmentRef rulesRef(m.EquipmentRef ref) => r.EquipmentRef(
  r.EquipmentKind.values.byName(ref.kind.name),
  ref.equipmentId,
);

/// The rules' copies of [refs]; `null` stays `null`.
List<r.EquipmentRef>? rulesRefs(List<m.EquipmentRef>? refs) =>
    refs?.map(rulesRef).toList();

/// A template's target as the rules read it.
r.SetTarget rulesTarget(m.SetTarget target) => r.SetTarget(
  setNumber: target.setNumber,
  minReps: target.minReps,
  maxReps: target.maxReps,
  rirTarget: target.rirTarget,
  setType: target.setType.rules,
  amrapTargetReps: target.amrapTargetReps,
);

/// A stored set as the rules read it.
r.WorkoutSet rulesSet(m.WorkoutSetModel set) => r.WorkoutSet(
  id: set.id,
  index: set.index,
  authorId: set.authorId,
  reps: set.reps,
  weightKg: set.weightKg,
  durationSec: set.durationSec,
  distanceMeters: set.distanceMeters,
  rpe: set.rpe,
  side: set.side?.rules,
  kind: set.kind.rules,
  parentSetId: set.parentSetId,
  targetReps: set.targetReps,
  bands: set.bands,
  weightUnit: set.weightUnit?.rules,
  loadCount: set.loadCount,
  machineBaseKg: set.machineBaseKg,
  isWarmup: set.isWarmup,
  completedAt: set.completedAt,
);

/// A stored exercise as the rules read it, lifted on its active variation.
r.WorkoutExercise rulesExercise(m.WorkoutExerciseModel exercise) =>
    r.WorkoutExercise(
      id: exercise.id,
      templateId: exercise.templateId,
      name: exercise.name,
      trackingMode: exercise.trackingMode.rules,
      index: exercise.index,
      imageName: exercise.imageName,
      sets: exercise.sets.map(rulesSet).toList(),
      setTargets: exercise.setTargets.map(rulesTarget).toList(),
      supersetGroupId: exercise.supersetGroupId,
      restSeconds: exercise.restSeconds,
      weightUnit: exercise.weightUnit?.rules,
      loadsPerSet: exercise.loadsPerSet,
      resistanceEquipment: rulesRefs(
        exercise.activeVariation?.resistanceEquipment,
      ),
    );

/// A stored session as the rules read it.
r.WorkoutSession rulesSession(m.WorkoutSessionModel session) =>
    r.WorkoutSession(
      exercises: session.exercises.map(rulesExercise).toList(),
      isDeload: session.isDeload,
    );

/// The rules' settings out of the stored ones. An exercise type this build
/// does not know is left out of the rests by type, as Swift's lookup by raw
/// value would never find it.
r.WorkoutSettings rulesSettings(m.WorkoutSettings settings) =>
    r.WorkoutSettings(
      supersetAutoScroll: settings.supersetAutoScroll,
      exerciseAutoNext: settings.exerciseAutoNext,
      useRestTimers: settings.useRestTimers,
      restAfterLastWarmUp: settings.restAfterLastWarmUp,
      restBetweenExercises: settings.restBetweenExercises,
      restBetweenSideSets: settings.restBetweenSideSets,
      supersetTransitionRestSeconds: settings.supersetTransitionRestSeconds,
      intraSetRestSeconds: settings.intraSetRestSeconds,
      intraSetRestMyoSeconds: settings.intraSetRestMyoSeconds,
      intraSetRestPauseSeconds: settings.intraSetRestPauseSeconds,
      intraSetRestClusterSeconds: settings.intraSetRestClusterSeconds,
      warmUpRestScaling: settings.warmUpRestScaling,
      betweenExercisesRestScaling: settings.betweenExercisesRestScaling,
      sideSetRestScaling: settings.sideSetRestScaling,
      restDurationsByExerciseType: {
        for (final type in r.ExerciseType.values)
          type: ?settings.restDurationsByExerciseType[type.name],
      },
      defaultRestDurationSeconds: settings.defaultRestDurationSeconds,
      setPlanning: settings.setPlanning,
      amrapRaisesTarget: settings.amrapRaisesTarget,
      amrapAddsWeightAtTarget: settings.amrapAddsWeightAtTarget,
      amrapAddsWeight: settings.amrapAddsWeight,
    );

/// [set], from the rules, as a stored set: [original] (the stored set it came
/// from) keeps what the rules do not carry, and a raw value the rules left
/// as it was is kept as stored. A set without an original is created at
/// [now].
m.WorkoutSetModel modelSet(
  r.WorkoutSet set, {
  required m.WorkoutSetModel? original,
  required DateTime now,
}) {
  String? raw<T>(
    T? rules,
    T? stored,
    String? storedRaw,
    String? Function() fresh,
  ) => original != null && rules == stored ? storedRaw : fresh();
  return m.WorkoutSetModel(
    id: set.id,
    authorId: set.authorId,
    index: set.index,
    isWarmup: set.isWarmup,
    dateCreated: original?.dateCreated ?? now,
    reps: set.reps,
    weightKg: set.weightKg,
    durationSec: set.durationSec,
    distanceMeters: set.distanceMeters,
    rpe: set.rpe,
    sideRawValue: raw(
      set.side,
      original?.side?.rules,
      original?.sideRawValue,
      () => set.side?.model.value,
    ),
    // Swift stores a standard set's kind as nothing.
    kindRawValue: raw(
      set.kind,
      original?.kind.rules,
      original?.kindRawValue,
      () => set.kind == r.SetKind.standard ? null : set.kind.model.value,
    ),
    parentSetId: set.parentSetId,
    targetReps: set.targetReps,
    bands: set.bands,
    weightUnitRawValue: raw(
      set.weightUnit,
      original?.weightUnit?.rules,
      original?.weightUnitRawValue,
      () => set.weightUnit?.model.value,
    ),
    loadCount: set.loadCount,
    machineBaseKg: set.machineBaseKg,
    completedAt: set.completedAt,
  );
}

/// [sets], from the rules, as stored sets, each matched by id among
/// [originals].
List<m.WorkoutSetModel> modelSets(
  List<r.WorkoutSet> sets, {
  required List<m.WorkoutSetModel> originals,
  required DateTime now,
}) {
  final byId = {for (final set in originals) set.id: set};
  return [
    for (final set in sets) modelSet(set, original: byId[set.id], now: now),
  ];
}

/// [exercises] in [rules]' order with [rules]' sets: the rules move
/// exercises and change sets, and nothing else of an exercise.
List<m.WorkoutExerciseModel> modelExercises(
  List<r.WorkoutExercise> rules, {
  required List<m.WorkoutExerciseModel> exercises,
  required DateTime now,
}) {
  final byId = {for (final exercise in exercises) exercise.id: exercise};
  return [
    for (final exercise in rules)
      if (byId[exercise.id] case final stored?)
        stored.copyWith(
          sets: modelSets(exercise.sets, originals: stored.sets, now: now),
        ),
  ];
}
