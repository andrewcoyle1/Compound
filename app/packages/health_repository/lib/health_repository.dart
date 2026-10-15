/// Apple Health (HealthKit) and Health Connect through the `health`
/// package: permissions, onboarding's prefill reads, the steps, weigh-in
/// and food imports, and the weigh-in and workout exports, as the Swift app
/// uses Apple Health. In memory for the staging flavor.
library;

export 'package:compound_models/compound_models.dart'
    show Gender, NutrientKey, WorkoutSessionModel;
export 'package:health/health.dart' show HealthDataAccess, HealthDataType;

export 'src/fake_health_platform.dart';
export 'src/health_package_platform.dart';
export 'src/health_platform.dart';
export 'src/health_repository.dart';
export 'src/health_scope.dart';
