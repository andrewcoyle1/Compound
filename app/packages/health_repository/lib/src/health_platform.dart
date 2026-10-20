import 'package:compound_models/compound_models.dart';
import 'package:health_repository/src/health_scope.dart';

/// One reading of a quantity in Apple Health or Health Connect.
class const HealthSample({
  /// The sample's id there, upper case as Swift's `UUID` writes it.
  required final String uuid,

  /// The value: kilograms for weight, percent (0 to 100) for body fat.
  required final double value,

  /// When it was measured.
  required final DateTime date,
}) {
  /// Creates a [HealthSample].
  this;
}

/// What the app needs from the platform's health store, in the units and
/// shapes the Swift services hand over (`HealthService`,
/// `HealthKitStepsService`, `HealthKitWeightService`,
/// `HealthKitNutritionService`). `HealthPackagePlatform` implements it on
/// the `health` package; `FakeHealthPlatform` in memory.
///
/// Reads throw when the store cannot be read. Days are the device's local
/// days, keyed by their midnight.
abstract interface class HealthPlatform {
  /// Whether the store can be used: HealthKit on this device, or Health
  /// Connect installed and up to date.
  Future<bool> isAvailable();

  /// Shows the permission sheet for [scope]. True when the request ran:
  /// HealthKit never says whether reading was allowed.
  Future<bool> requestAuthorization(HealthScope scope);

  /// Whether saving workouts still needs the person's answer or was
  /// refused (Swift `needsAuthorisationForRequiredTypes`).
  Future<bool> needsWorkoutAuthorization();

  /// The earliest time from [wanted] on that reads can reach: [wanted],
  /// unless Health Connect withholds older history.
  Future<DateTime> readableSince(DateTime wanted);

  /// Each day's step total from [start] up to [end], keyed by the day.
  /// Days with no steps are left out. Totals count a step recorded by two
  /// devices once.
  Future<Map<DateTime, int>> dailySteps(DateTime start, DateTime end);

  /// Each day's food totals from [start] up to [end], keyed by the day,
  /// holding only `calories` (kcal), `protein`, `carbs` and `fatTotal`
  /// (grams). Days with nothing recorded are left out.
  Future<Map<DateTime, Map<NutrientKey, double>>> dailyNutrition(
    DateTime start,
    DateTime end,
  );

  /// Weigh-ins from [start] up to [end], in kilograms, leaving out those
  /// this app wrote: they are weigh-ins logged here, which have an entry.
  Future<List<HealthSample>> weights(DateTime start, DateTime end);

  /// Body fat readings from [start] up to [end], in percent, leaving out
  /// those this app wrote.
  Future<List<HealthSample>> bodyFat(DateTime start, DateTime end);

  /// The date of birth held, or null.
  Future<DateTime?> dateOfBirth();

  /// The biological sex held, or null when it is not male or female:
  /// neither says which coefficient applies, so the person picks.
  Future<Gender?> sex();

  /// The latest height, in centimetres, or null.
  Future<double?> latestHeightCentimeters();

  /// The latest weight, in kilograms, or null.
  Future<double?> latestWeightKilograms();

  /// Saves a weigh-in and returns its id, upper case, or null when the
  /// store gave none.
  Future<String?> writeWeight(double kilograms, DateTime date);

  /// Saves a strength training workout. True when it was saved.
  Future<bool> writeStrengthWorkout({
    required DateTime start,
    required DateTime end,
    String? title,
  });
}
