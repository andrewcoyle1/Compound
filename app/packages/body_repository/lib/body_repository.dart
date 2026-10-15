/// Reads the signed-in user's body measurements, steps, analytics settings
/// and current weight goal from Firestore, or from memory in the staging
/// flavor, and saves measurements, steps and goals.
library;

export 'package:compound_models/compound_models.dart'
    show
        AnalyticsSettings,
        BodyMeasurementEntry,
        GoalStatus,
        OverarchingObjective,
        StepsModel,
        StepsSource,
        WeightGoal,
        WeightSource;

export 'src/body_repository.dart';
export 'src/body_rules.dart' show clearableMeasurementFields;
export 'src/firestore_body_repository.dart';
export 'src/in_memory_body_repository.dart';
export 'src/sample_body.dart';
