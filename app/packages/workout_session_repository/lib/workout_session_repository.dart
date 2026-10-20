/// Reads and writes the signed-in user's workout sessions in Firestore, or
/// in memory in the staging flavor. Writes are whole sessions merged and the
/// `week_streak_count` field, held to the Firestore contract
/// (docs/specs/flutter/firestore-contract.md).
library;

export 'package:compound_models/compound_models.dart'
    show
        EquipmentKind,
        EquipmentRef,
        EquipmentVariation,
        ExerciseWeightUnit,
        SetKind,
        SetSide,
        SetTarget,
        SetTargetSetType,
        TrackingMode,
        WorkoutExerciseModel,
        WorkoutSessionModel,
        WorkoutSetModel;

export 'src/firestore_workout_session_repository.dart';
export 'src/in_memory_workout_session_repository.dart';
export 'src/sample_workout_sessions.dart';
export 'src/workout_session_repository.dart';
