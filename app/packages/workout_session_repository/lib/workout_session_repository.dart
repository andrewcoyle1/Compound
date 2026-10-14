/// Reads the signed-in user's workout sessions from Firestore, or from
/// memory in the staging flavor. Read-only until the session contract has
/// been exercised by writes (docs/specs/flutter/firestore-contract.md).
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
