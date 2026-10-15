import 'package:compound/l10n/l10n.dart';
import 'package:compound_models/compound_models.dart';

/// The display names of the library's enums, as the Swift enums' `name`
/// (and `EquipmentKind.sectionTitle`).
extension LibraryNames on AppLocalizations {
  String muscleName(Muscles value) => switch (value) {
    Muscles.triceps => muscleTriceps,
    Muscles.upperTraps => muscleUpperTraps,
    Muscles.obliques => muscleObliques,
    Muscles.neck => muscleNeck,
    Muscles.lats => muscleLats,
    Muscles.forearms => muscleForearms,
    Muscles.sideDelts => muscleSideDelts,
    Muscles.rearDelts => muscleRearDelts,
    Muscles.frontDelts => muscleFrontDelts,
    Muscles.chest => muscleChest,
    Muscles.biceps => muscleBiceps,
    Muscles.upperBack => muscleUpperBack,
    Muscles.lowerBack => muscleLowerBack,
    Muscles.abs => muscleAbs,
    Muscles.serratus => muscleSerratus,
    Muscles.quads => muscleQuads,
    Muscles.hamstrings => muscleHamstrings,
    Muscles.glutes => muscleGlutes,
    Muscles.calves => muscleCalves,
    Muscles.abductors => muscleAbductors,
    Muscles.adductors => muscleAdductors,
    Muscles.tibialis => muscleTibialis,
  };

  String exerciseTypeName(ExerciseType value) => switch (value) {
    ExerciseType.compoundUpper => exerciseTypeCompoundUpper,
    ExerciseType.compoundLower => exerciseTypeCompoundLower,
    ExerciseType.isolationUpper => exerciseTypeIsolationUpper,
    ExerciseType.isolationLower => exerciseTypeIsolationLower,
    ExerciseType.core => exerciseTypeCore,
  };

  String lateralityName(Laterality value) => switch (value) {
    Laterality.bilateral => lateralityBilateral,
    Laterality.unilateral => lateralityUnilateral,
    Laterality.assymetrical => lateralityAssymetrical,
    Laterality.unilateralBilateral => lateralityUnilateralBilateral,
  };

  String metricName(TrackableExerciseMetric value) => switch (value) {
    TrackableExerciseMetric.reps => metricReps,
    TrackableExerciseMetric.repsPerSide => metricRepsPerSide,
    TrackableExerciseMetric.weight => metricWeight,
    TrackableExerciseMetric.weightPerSide => metricWeightPerSide,
    TrackableExerciseMetric.weightPerSidePersistent =>
      metricWeightPerSidePersistent,
    TrackableExerciseMetric.weightPerSideAssistance =>
      metricWeightPerSideAssistance,
    TrackableExerciseMetric.duration => metricDuration,
    TrackableExerciseMetric.durationPerSide => metricDurationPerSide,
    TrackableExerciseMetric.distanceShort => metricDistanceShort,
    TrackableExerciseMetric.distanceShortPerSide => metricDistanceShortPerSide,
    TrackableExerciseMetric.distanceLong => metricDistanceLong,
  };

  String equipmentKindName(EquipmentKind value) => switch (value) {
    EquipmentKind.freeWeight => equipmentKindFreeWeight,
    EquipmentKind.loadableBar => equipmentKindLoadableBar,
    EquipmentKind.fixedWeightBar => equipmentKindFixedWeightBar,
    EquipmentKind.bands => equipmentKindBands,
    EquipmentKind.bodyWeight => equipmentKindBodyWeight,
    EquipmentKind.supportEquipment => equipmentKindSupportEquipment,
    EquipmentKind.accessoryEquipment => equipmentKindAccessoryEquipment,
    EquipmentKind.loadableAccessoryEquipment =>
      equipmentKindLoadableAccessoryEquipment,
    EquipmentKind.cableMachine => equipmentKindCableMachine,
    EquipmentKind.plateLoadedMachine => equipmentKindPlateLoadedMachine,
    EquipmentKind.pinLoadedMachine => equipmentKindPinLoadedMachine,
  };
}
