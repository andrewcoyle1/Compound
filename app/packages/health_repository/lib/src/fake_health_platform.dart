import 'package:compound_models/compound_models.dart';
import 'package:health_repository/src/days.dart';
import 'package:health_repository/src/health_platform.dart';
import 'package:health_repository/src/health_scope.dart';

/// A step count, at the time it was recorded.
typedef FakeSteps = ({DateTime date, int steps});

/// Food from another app, at the time it was eaten.
typedef FakeFood = ({DateTime date, Map<NutrientKey, double> nutrients});

/// [HealthPlatform] in memory, for the staging flavor and tests: an Apple
/// Health whose contents the caller sets. Like the real store, what this
/// app writes is not read back.
class FakeHealthPlatform implements HealthPlatform {
  /// Creates a [FakeHealthPlatform] holding the given readings.
  new({
    this.available = true,
    this.granted = true,
    List<FakeSteps> steps = const [],
    List<FakeFood> food = const [],
    List<HealthSample> weights = const [],
    List<HealthSample> bodyFat = const [],
    this.birthDate,
    this.biologicalSex,
    this.heightCentimeters,
  }) : steps = List.of(steps),
       food = List.of(food),
       weightSamples = List.of(weights),
       bodyFatSamples = List.of(bodyFat);

  /// Whether the store can be used.
  bool available;

  /// What a permission request answers.
  bool granted;

  /// When set, every read and write throws it.
  Exception? error;

  /// Step counts held.
  final List<FakeSteps> steps;

  /// Food held.
  final List<FakeFood> food;

  /// Weigh-ins held, from other apps.
  final List<HealthSample> weightSamples;

  /// Body fat readings held, from other apps.
  final List<HealthSample> bodyFatSamples;

  /// The date of birth held.
  DateTime? birthDate;

  /// The biological sex held.
  Gender? biologicalSex;

  /// The latest height held.
  double? heightCentimeters;

  /// The scopes asked for, in order.
  final requested = <HealthScope>[];

  /// The weigh-ins this app wrote, in order.
  final writtenWeights = <HealthSample>[];

  /// The workouts this app wrote, in order.
  final writtenWorkouts = <({DateTime start, DateTime end, String? title})>[];

  void _check() {
    if (error case final Exception error) throw error;
  }

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> requestAuthorization(HealthScope scope) async {
    _check();
    requested.add(scope);
    return granted;
  }

  @override
  Future<bool> needsWorkoutAuthorization() async => !granted;

  @override
  Future<DateTime> readableSince(DateTime wanted) async => wanted;

  @override
  Future<Map<DateTime, int>> dailySteps(DateTime start, DateTime end) async {
    _check();
    final totals = <DateTime, int>{};
    for (final (:date, :steps) in this.steps) {
      if (date.isBefore(start) || !date.isBefore(end)) continue;
      final day = startOfDay(date);
      totals[day] = (totals[day] ?? 0) + steps;
    }
    return totals;
  }

  @override
  Future<Map<DateTime, Map<NutrientKey, double>>> dailyNutrition(
    DateTime start,
    DateTime end,
  ) async {
    _check();
    final totals = <DateTime, Map<NutrientKey, double>>{};
    for (final (:date, :nutrients) in food) {
      if (date.isBefore(start) || !date.isBefore(end)) continue;
      final day = totals.putIfAbsent(startOfDay(date), () => {});
      for (final MapEntry(:key, :value) in nutrients.entries) {
        day[key] = (day[key] ?? 0) + value;
      }
    }
    return totals;
  }

  @override
  Future<List<HealthSample>> weights(DateTime start, DateTime end) async =>
      _between(weightSamples, start, end);

  @override
  Future<List<HealthSample>> bodyFat(DateTime start, DateTime end) async =>
      _between(bodyFatSamples, start, end);

  List<HealthSample> _between(
    List<HealthSample> samples,
    DateTime start,
    DateTime end,
  ) {
    _check();
    return [
      for (final sample in samples)
        if (!sample.date.isBefore(start) && sample.date.isBefore(end)) sample,
    ];
  }

  @override
  Future<DateTime?> dateOfBirth() async {
    _check();
    return birthDate;
  }

  @override
  Future<Gender?> sex() async {
    _check();
    return biologicalSex;
  }

  @override
  Future<double?> latestHeightCentimeters() async {
    _check();
    return heightCentimeters;
  }

  @override
  Future<double?> latestWeightKilograms() async {
    _check();
    final all = [...weightSamples, ...writtenWeights];
    if (all.isEmpty) return null;
    return all.reduce((a, b) => b.date.isAfter(a.date) ? b : a).value;
  }

  @override
  Future<String?> writeWeight(double kilograms, DateTime date) async {
    _check();
    final uuid =
        '00000000-0000-4000-8000-'
        '${(writtenWeights.length + 1).toString().padLeft(12, '0')}';
    writtenWeights.add(HealthSample(uuid: uuid, value: kilograms, date: date));
    return uuid;
  }

  @override
  Future<bool> writeStrengthWorkout({
    required DateTime start,
    required DateTime end,
    String? title,
  }) async {
    _check();
    writtenWorkouts.add((start: start, end: end, title: title));
    return true;
  }
}

/// A [FakeHealthPlatform] for staging, as of [now]: a fortnight of steps
/// from a phone and a watch, a week of morning weigh-ins from a smart
/// scale with body fat, two days of food from another app, and the
/// characteristics onboarding fills from.
FakeHealthPlatform sampleHealthPlatform(DateTime now) {
  final today = startOfDay(now);
  DateTime at(int daysAgo, int hour) =>
      DateTime(today.year, today.month, today.day - daysAgo, hour);
  return FakeHealthPlatform(
    steps: [
      for (var day = 0; day < 14; day++) ...[
        (date: at(day, 9), steps: 3200 + day * 150),
        (date: at(day, 18), steps: 4100 + (day % 3) * 900),
      ],
    ],
    food: [
      for (final day in [1, 2])
        (
          date: at(day, 13),
          nutrients: {
            NutrientKey.calories: 2150 + day * 40,
            NutrientKey.protein: 140,
            NutrientKey.carbs: 230,
            NutrientKey.fatTotal: 70,
          },
        ),
    ],
    weights: [
      for (var day = 0; day < 7; day++)
        HealthSample(
          uuid: 'A0000000-0000-4000-8000-${day.toString().padLeft(12, '0')}',
          value: 81.4 - day * 0.15,
          date: at(day, 7),
        ),
    ],
    bodyFat: [
      for (var day = 0; day < 7; day++)
        HealthSample(
          uuid: 'B0000000-0000-4000-8000-${day.toString().padLeft(12, '0')}',
          value: 18.6 + day * 0.05,
          date: at(day, 7),
        ),
    ],
    birthDate: DateTime(1994, 5, 17),
    biologicalSex: Gender.female,
    heightCentimeters: 168,
  );
}
