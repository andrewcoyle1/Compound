import 'package:health/health.dart';

/// What one feature needs from Apple Health or Health Connect (Swift
/// `HealthDataScope`). Each feature asks for its own scope when it is first
/// used, so the permission sheet lists only what that feature reads and
/// writes. Add a type only together with the code that uses it.
enum HealthScope {
  /// Saving a finished workout, with its heart rate and active energy.
  workouts,

  /// The Steps screen: reads step counts.
  steps,

  /// Logging or viewing weight: reads and writes weight, reads body fat.
  bodyMeasurements,

  /// The Nutrition tab: reads food logged in other apps, as daily energy
  /// and macro totals.
  nutrition,

  /// Onboarding's "Fill from Apple Health": the date of birth.
  dateOfBirth,

  /// Onboarding's "Fill from Apple Health": biological sex.
  sex,

  /// Onboarding's "Fill from Apple Health": height.
  height,

  /// Onboarding's "Fill from Apple Health": weight.
  weight;

  /// The types this scope reads and writes, with the access asked for each,
  /// exactly as Swift's `typesToShare` and `typesToRead`
  /// (`HealthService.swift`). [appleHealth] picks HealthKit's types over
  /// Health Connect's: Health Connect keeps food as one `NUTRITION` record,
  /// and holds no date of birth or sex, so those scopes ask for nothing.
  Map<HealthDataType, HealthDataAccess> permissions({
    required bool appleHealth,
  }) => switch (this) {
    workouts => const {
      HealthDataType.WORKOUT: HealthDataAccess.READ_WRITE,
      HealthDataType.ACTIVE_ENERGY_BURNED: HealthDataAccess.READ_WRITE,
      HealthDataType.HEART_RATE: HealthDataAccess.READ_WRITE,
    },
    steps => const {HealthDataType.STEPS: HealthDataAccess.READ},
    bodyMeasurements => const {
      HealthDataType.WEIGHT: HealthDataAccess.READ_WRITE,
      HealthDataType.BODY_FAT_PERCENTAGE: HealthDataAccess.READ,
    },
    nutrition =>
      appleHealth
          ? const {
              HealthDataType.DIETARY_ENERGY_CONSUMED: HealthDataAccess.READ,
              HealthDataType.DIETARY_PROTEIN_CONSUMED: HealthDataAccess.READ,
              HealthDataType.DIETARY_CARBS_CONSUMED: HealthDataAccess.READ,
              HealthDataType.DIETARY_FATS_CONSUMED: HealthDataAccess.READ,
            }
          : const {HealthDataType.NUTRITION: HealthDataAccess.READ},
    dateOfBirth =>
      appleHealth
          ? const {HealthDataType.BIRTH_DATE: HealthDataAccess.READ}
          : const {},
    sex =>
      appleHealth
          ? const {HealthDataType.GENDER: HealthDataAccess.READ}
          : const {},
    height => const {HealthDataType.HEIGHT: HealthDataAccess.READ},
    weight => const {HealthDataType.WEIGHT: HealthDataAccess.READ},
  };

  /// Whether the import reads this scope's history, which Health Connect
  /// keeps behind a permission of its own past 30 days.
  bool get readsHistory =>
      this == steps || this == bodyMeasurements || this == nutrition;
}
