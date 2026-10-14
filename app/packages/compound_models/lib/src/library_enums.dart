import 'package:compound_models/src/firestore_enum.dart';

/// A muscle an exercise works (Swift `Muscles`), also the key of an exercise's
/// `muscle_groups` map.
enum Muscles implements FirestoreEnum {
  /// `triceps`.
  triceps('triceps'),

  /// `upperTraps`.
  upperTraps('upperTraps'),

  /// `obliques`.
  obliques('obliques'),

  /// `neck`.
  neck('neck'),

  /// `lats`.
  lats('lats'),

  /// `forearms`.
  forearms('forearms'),

  /// `sideDelts`.
  sideDelts('sideDelts'),

  /// `rearDelts`.
  rearDelts('rearDelts'),

  /// `frontDelts`.
  frontDelts('frontDelts'),

  /// `chest`.
  chest('chest'),

  /// `biceps`.
  biceps('biceps'),

  /// `upperBack`.
  upperBack('upperBack'),

  /// `lowerBack`.
  lowerBack('lowerBack'),

  /// `abs`.
  abs('abs'),

  /// `serratus`.
  serratus('serratus'),

  /// `quads`.
  quads('quads'),

  /// `hamstrings`.
  hamstrings('hamstrings'),

  /// `glutes`.
  glutes('glutes'),

  /// `calves`.
  calves('calves'),

  /// `abductors`.
  abductors('abductors'),

  /// `adductors`.
  adductors('adductors'),

  /// `tibialis`.
  tibialis('tibialis');

  new(this.value);

  @override
  final String value;
}

/// How much an exercise works a muscle (Swift `MuscleTargetType`).
enum MuscleTargetType implements FirestoreEnum {
  /// `primary`.
  primary('primary'),

  /// `secondary`.
  secondary('secondary');

  new(this.value);

  @override
  final String value;
}

/// What an exercise's sets can record (Swift `TrackableExerciseMetric`).
enum TrackableExerciseMetric implements FirestoreEnum {
  /// `reps`.
  reps('reps'),

  /// `repsPerSide`.
  repsPerSide('repsPerSide'),

  /// `weight`.
  weight('weight'),

  /// `weightPerSide`.
  weightPerSide('weightPerSide'),

  /// `weightPerSidePersistent`.
  weightPerSidePersistent('weightPerSidePersistent'),

  /// `weightPerSideAssistance`.
  weightPerSideAssistance('weightPerSideAssistance'),

  /// `duration`.
  duration('duration'),

  /// `durationPerSide`.
  durationPerSide('durationPerSide'),

  /// `distanceShort`.
  distanceShort('distanceShort'),

  /// `distanceShortPerSide`.
  distanceShortPerSide('distanceShortPerSide'),

  /// `distanceLong`.
  distanceLong('distanceLong');

  new(this.value);

  @override
  final String value;
}

/// An exercise's movement class (Swift `ExerciseType`), which keys the
/// per-type rests.
enum ExerciseType implements FirestoreEnum {
  /// `compoundUpper`.
  compoundUpper('compoundUpper'),

  /// `compoundLower`.
  compoundLower('compoundLower'),

  /// `isolationUpper`.
  isolationUpper('isolationUpper'),

  /// `isolationLower`.
  isolationLower('isolationLower'),

  /// `core`.
  core('core');

  new(this.value);

  @override
  final String value;
}

/// Whether an exercise works one side at a time (Swift `Laterality`).
enum Laterality implements FirestoreEnum {
  /// `bilateral`.
  bilateral('bilateral'),

  /// `unilateral`.
  unilateral('unilateral'),

  /// `assymetrical`, spelled as Swift stores it.
  assymetrical('assymetrical'),

  /// `unilateralBilateral`.
  unilateralBilateral('unilateralBilateral');

  new(this.value);

  @override
  final String value;
}

/// Which past session the tracker's previous values come from (Swift
/// `PreviousWorkoutReferenceOption`). The stored values are older than the
/// case names, and load-bearing.
enum PreviousWorkoutReferenceOption implements FirestoreEnum {
  /// `anyExercise`: the exercise's last time in any workout.
  anyExercise('anyExercise'),

  /// `anyWorkout`: this workout template's last session, the default.
  sameWorkout('anyWorkout'),

  /// `workoutsInProgram`: as [sameWorkout], within the current
  /// mesocycle.
  workoutsInMesocycle('workoutsInProgram');

  new(this.value);

  @override
  final String value;
}

/// What a new session's sets are filled with (Swift `InitialLogFillOption`).
enum InitialLogFillOption implements FirestoreEnum {
  /// `smartProgression`.
  smartProgression('smartProgression'),

  /// `previousValues`.
  previousValues('previousValues'),

  /// `empty`.
  empty('empty');

  new(this.value);

  @override
  final String value;
}

/// Whether smart progression adds weight or reps first (Swift
/// `ProgressionAdjustmentMode`).
enum ProgressionAdjustmentMode implements FirestoreEnum {
  /// `weightFirst`.
  weightFirst('weightFirst'),

  /// `repsFirst`.
  repsFirst('repsFirst');

  new(this.value);

  @override
  final String value;
}
