/// Reads the signed-in user's training library (exercises, workout
/// templates, gym profiles, exercise and workout settings) from Firestore,
/// or from memory in the staging flavor, beside the Swift app's bundled
/// system exercises and workouts. It writes gym profiles and exercise
/// settings (docs/specs/flutter/firestore-contract.md).
library;

export 'package:compound_models/compound_models.dart'
    show
        Bands,
        BandsAvailable,
        BarBaseWeight,
        BodyWeights,
        BodyWeightsAvailable,
        DeloadType,
        ExerciseModel,
        ExerciseSettingsModel,
        ExerciseType,
        ExerciseWeightUnit,
        FixedWeightBars,
        FreeWeights,
        FreeWeightsAvailable,
        GymEquipmentCatalogue,
        GymEquipmentItem,
        GymEquipmentKeys,
        GymProfileModel,
        GymProfileModelKeys,
        InitialLogFillOption,
        Laterality,
        LoadableAccessoryEquipment,
        LoadableBars,
        Mesocycle,
        MicrocycleSetTargets,
        MuscleTargetType,
        Muscles,
        PlainEquipment,
        PlateLoadedMachine,
        PreviousWorkoutReferenceOption,
        ProgressionAdjustmentMode,
        SetTarget,
        SetTargetSetType,
        StackMachine,
        TrackableExerciseMetric,
        WeightStack,
        WorkoutSettings,
        WorkoutTemplateExercise,
        WorkoutTemplateModel;

export 'src/firestore_training_library_repository.dart';
export 'src/gym_editor_rules.dart';
export 'src/in_memory_training_library_repository.dart';
export 'src/prebuilt_catalogue.dart';
export 'src/sample_training_library.dart';
export 'src/training_library_repository.dart';
export 'src/workout_editor_rules.dart';
