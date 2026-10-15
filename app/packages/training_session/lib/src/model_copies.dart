/// Copies of the stored models with some fields replaced, which
/// `compound_models` leaves out: its types mirror Firestore and nothing more.
library;

import 'package:compound_models/compound_models.dart';

const Object _keep = Object();

T? _or<T>(Object? value, T? current) =>
    identical(value, _keep) ? current : value as T?;

/// A copy of a set; pass `null` to clear a nullable field.
extension WorkoutSetModelCopy on WorkoutSetModel {
  WorkoutSetModel copyWith({
    String? id,
    int? index,
    bool? isWarmup,
    DateTime? dateCreated,
    Object? reps = _keep,
    Object? weightKg = _keep,
    Object? durationSec = _keep,
    Object? distanceMeters = _keep,
    Object? rpe = _keep,
    Object? sideRawValue = _keep,
    Object? kindRawValue = _keep,
    Object? parentSetId = _keep,
    Object? targetReps = _keep,
    Object? bands = _keep,
    Object? weightUnitRawValue = _keep,
    Object? loadCount = _keep,
    Object? machineBaseKg = _keep,
    Object? completedAt = _keep,
  }) => WorkoutSetModel(
    id: id ?? this.id,
    authorId: authorId,
    index: index ?? this.index,
    isWarmup: isWarmup ?? this.isWarmup,
    dateCreated: dateCreated ?? this.dateCreated,
    reps: _or(reps, this.reps),
    weightKg: _or<num>(weightKg, this.weightKg)?.toDouble(),
    durationSec: _or(durationSec, this.durationSec),
    distanceMeters: _or<num>(distanceMeters, this.distanceMeters)?.toDouble(),
    rpe: _or<num>(rpe, this.rpe)?.toDouble(),
    sideRawValue: _or(sideRawValue, this.sideRawValue),
    kindRawValue: _or(kindRawValue, this.kindRawValue),
    parentSetId: _or(parentSetId, this.parentSetId),
    targetReps: _or(targetReps, this.targetReps),
    bands: _or(bands, this.bands),
    weightUnitRawValue: _or(weightUnitRawValue, this.weightUnitRawValue),
    loadCount: _or(loadCount, this.loadCount),
    machineBaseKg: _or<num>(machineBaseKg, this.machineBaseKg)?.toDouble(),
    completedAt: _or(completedAt, this.completedAt),
  );
}

/// A copy of an exercise; pass `null` to clear a nullable field.
extension WorkoutExerciseModelCopy on WorkoutExerciseModel {
  WorkoutExerciseModel copyWith({
    String? id,
    String? templateId,
    String? name,
    TrackingMode? trackingMode,
    int? index,
    List<WorkoutSetModel>? sets,
    List<SetTarget>? setTargets,
    List<EquipmentVariation>? equipmentVariations,
    List<String>? substituteExerciseIds,
    Object? notes = _keep,
    Object? imageName = _keep,
    Object? chosenVariationId = _keep,
    Object? supersetGroupId = _keep,
    Object? planNotes = _keep,
    Object? planSlotId = _keep,
    Object? restSeconds = _keep,
    Object? linkUrl = _keep,
    Object? weightUnit = _keep,
    Object? loadsPerSet = _keep,
    Object? machineBaseKg = _keep,
  }) => WorkoutExerciseModel(
    id: id ?? this.id,
    authorId: authorId,
    templateId: templateId ?? this.templateId,
    name: name ?? this.name,
    trackingMode: trackingMode ?? this.trackingMode,
    index: index ?? this.index,
    sets: sets ?? this.sets,
    setTargets: setTargets ?? this.setTargets,
    equipmentVariations: equipmentVariations ?? this.equipmentVariations,
    substituteExerciseIds: substituteExerciseIds ?? this.substituteExerciseIds,
    notes: _or(notes, this.notes),
    imageName: _or(imageName, this.imageName),
    chosenVariationId: _or(chosenVariationId, this.chosenVariationId),
    supersetGroupId: _or(supersetGroupId, this.supersetGroupId),
    planNotes: _or(planNotes, this.planNotes),
    planSlotId: _or(planSlotId, this.planSlotId),
    restSeconds: _or(restSeconds, this.restSeconds),
    linkUrl: _or(linkUrl, this.linkUrl),
    weightUnit: _or(weightUnit, this.weightUnit),
    loadsPerSet: _or(loadsPerSet, this.loadsPerSet),
    machineBaseKg: _or<num>(machineBaseKg, this.machineBaseKg)?.toDouble(),
  );

  /// The variation it is lifted on: the chosen one, else the first
  /// (`WorkoutExerciseModel.activeVariation`).
  EquipmentVariation? get activeVariation =>
      equipmentVariations
          .where((variation) => variation.id == chosenVariationId)
          .firstOrNull ??
      equipmentVariations.firstOrNull;
}

/// A copy of a session; pass `null` to clear a nullable field.
extension WorkoutSessionModelCopy on WorkoutSessionModel {
  WorkoutSessionModel copyWith({
    String? name,
    DateTime? dateCreated,
    DateTime? dateModified,
    List<WorkoutExerciseModel>? exercises,
    Object? endedAt = _keep,
    Object? notes = _keep,
    Object? pausedSeconds = _keep,
    Object? weekStreakCount = _keep,
    Object? isDeload = _keep,
  }) => WorkoutSessionModel(
    id: id,
    authorId: authorId,
    name: name ?? this.name,
    workoutTemplateId: workoutTemplateId,
    mesocycleId: mesocycleId,
    dateCreated: dateCreated ?? this.dateCreated,
    dateModified: dateModified ?? this.dateModified,
    endedAt: _or(endedAt, this.endedAt),
    notes: _or(notes, this.notes),
    exercises: exercises ?? this.exercises,
    deletedAt: deletedAt,
    isRestDay: isRestDay,
    likedByUserIds: likedByUserIds,
    weekStreakCount: _or(weekStreakCount, this.weekStreakCount),
    pausedSeconds: _or<num>(pausedSeconds, this.pausedSeconds)?.toDouble(),
    stravaActivityId: stravaActivityId,
    gymProfileId: gymProfileId,
    isDeload: _or(isDeload, this.isDeload),
    hidden: hidden,
  );

  /// The [occurrence]th appearance of [templateId], from 0, in index order
  /// (`WorkoutSessionModel.exercise(templateId:occurrence:)`).
  WorkoutExerciseModel? exercise(String templateId, int occurrence) {
    final matches = _appearances(templateId);
    return occurrence >= 0 && occurrence < matches.length
        ? matches[occurrence]
        : null;
  }

  /// Which appearance of its exercise [exercise] is, from 0.
  int occurrenceOf(WorkoutExerciseModel exercise) {
    final index = _appearances(exercise.templateId)
        .indexWhere((e) => e.id == exercise.id);
    return index < 0 ? 0 : index;
  }

  List<WorkoutExerciseModel> _appearances(String templateId) =>
      exercises.where((e) => e.templateId == templateId).toList()
        ..sort((a, b) => a.index.compareTo(b.index));
}
