import 'package:compound_models/compound_models.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_repository/src/days.dart';
import 'package:health_repository/src/health_platform.dart';
import 'package:health_repository/src/health_scope.dart';

/// [HealthPlatform] on the `health` package: HealthKit on iOS, Health
/// Connect on Android.
class HealthPackagePlatform implements HealthPlatform {
  /// Creates a [HealthPackagePlatform]. `ownSourceId` is this app's bundle
  /// id (iOS) or package name (Android), which Health reports as the source
  /// of what the app wrote. `platform` defaults to the running one.
  new({
    required this._ownSourceId,
    Health? health,
    TargetPlatform? platform,
    DateTime Function()? now,
  }) : _health = health ?? Health(),
       _appleHealth = (platform ?? defaultTargetPlatform) == TargetPlatform.iOS,
       _now = now ?? DateTime.now;

  final String _ownSourceId;
  final Health _health;
  final bool _appleHealth;
  final DateTime Function() _now;

  /// Characteristic and latest-value reads look this far back.
  static final _ever = DateTime.utc(1970);

  @override
  Future<bool> isAvailable() => _health.isHealthConnectAvailable();

  @override
  Future<bool> requestAuthorization(HealthScope scope) async {
    final permissions = scope.permissions(appleHealth: _appleHealth);
    if (permissions.isEmpty) return false;
    final granted = await _health.requestAuthorization(
      permissions.keys.toList(),
      permissions: permissions.values.toList(),
    );
    // Health Connect reads only 30 days before the first grant without
    // this; HealthKit has no such limit.
    if (!_appleHealth &&
        scope.readsHistory &&
        await _health.isHealthDataHistoryAvailable()) {
      await _health.requestHealthDataHistoryAuthorization();
    }
    return granted;
  }

  @override
  Future<bool> needsWorkoutAuthorization() async =>
      await _health.hasPermissions(
        const [HealthDataType.WORKOUT],
        permissions: const [HealthDataAccess.WRITE],
      ) !=
      true;

  @override
  Future<DateTime> readableSince(DateTime wanted) async {
    if (_appleHealth || await _health.isHealthDataHistoryAuthorized()) {
      return wanted;
    }
    final today = startOfDay(_now());
    final floor = DateTime(today.year, today.month, today.day - 30);
    return wanted.isAfter(floor) ? wanted : floor;
  }

  /// One aggregate per day, which both stores de-duplicate across devices.
  // ponytail: a call per day (366 for a year); one interval query per
  // platform if an import ever feels slow.
  @override
  Future<Map<DateTime, int>> dailySteps(DateTime start, DateTime end) async {
    final totals = <DateTime, int>{};
    for (var day = startOfDay(start); day.isBefore(end); day = nextDay(day)) {
      final total = await _health.getTotalStepsInInterval(day, nextDay(day));
      if (total == null) {
        throw StateError('Health gave no step total for $day');
      }
      if (total > 0) totals[day] = total;
    }
    return totals;
  }

  // ponytail: sums the raw samples, as HealthKit's statistics would for
  // food (one app per meal); a statistics query if two apps ever overlap.
  @override
  Future<Map<DateTime, Map<NutrientKey, double>>> dailyNutrition(
    DateTime start,
    DateTime end,
  ) async {
    final totals = <DateTime, Map<NutrientKey, double>>{};
    void add(DateTime date, NutrientKey key, num? amount) {
      if (amount == null) return;
      final day = totals.putIfAbsent(startOfDay(date), () => {});
      day[key] = (day[key] ?? 0) + amount;
    }

    final points = await _health.getHealthDataFromTypes(
      types: _appleHealth
          ? _appleNutrients.keys.toList()
          : const [HealthDataType.NUTRITION],
      startTime: start,
      endTime: end,
    );
    for (final point in points) {
      switch (point.value) {
        case final NutritionHealthValue food:
          add(point.dateFrom, NutrientKey.calories, food.calories);
          add(point.dateFrom, NutrientKey.protein, food.protein);
          add(point.dateFrom, NutrientKey.carbs, food.carbs);
          add(point.dateFrom, NutrientKey.fatTotal, food.fat);
        case final NumericHealthValue amount:
          final key = _appleNutrients[point.type];
          if (key != null) add(point.dateFrom, key, amount.numericValue);
      }
    }
    return totals;
  }

  static const Map<HealthDataType, NutrientKey> _appleNutrients = {
    HealthDataType.DIETARY_ENERGY_CONSUMED: NutrientKey.calories,
    HealthDataType.DIETARY_PROTEIN_CONSUMED: NutrientKey.protein,
    HealthDataType.DIETARY_CARBS_CONSUMED: NutrientKey.carbs,
    HealthDataType.DIETARY_FATS_CONSUMED: NutrientKey.fatTotal,
  };

  @override
  Future<List<HealthSample>> weights(DateTime start, DateTime end) =>
      _samples(HealthDataType.WEIGHT, start, end, scale: 1);

  /// HealthKit gives a fraction, Health Connect a percentage.
  @override
  Future<List<HealthSample>> bodyFat(DateTime start, DateTime end) => _samples(
    HealthDataType.BODY_FAT_PERCENTAGE,
    start,
    end,
    scale: _appleHealth ? 100 : 1,
  );

  Future<List<HealthSample>> _samples(
    HealthDataType type,
    DateTime start,
    DateTime end, {
    required double scale,
  }) async => [
    for (final point in await _numeric(type, start, end))
      if (point.$1.sourceId != _ownSourceId)
        HealthSample(
          uuid: point.$1.uuid.toUpperCase(),
          value: point.$2 * scale,
          date: point.$1.dateFrom,
        ),
  ];

  /// HealthKit reports a missing characteristic as 0.
  @override
  Future<DateTime?> dateOfBirth() async {
    if (!_appleHealth) return null;
    final seconds = await _characteristic(HealthDataType.BIRTH_DATE);
    return seconds == null || seconds == 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
  }

  /// `HKBiologicalSex`: 1 female, 2 male; not set (0) and other (3) give
  /// null, as in Swift.
  @override
  Future<Gender?> sex() async {
    if (!_appleHealth) return null;
    return switch (await _characteristic(HealthDataType.GENDER)) {
      1 => Gender.female,
      2 => Gender.male,
      _ => null,
    };
  }

  Future<num?> _characteristic(HealthDataType type) async {
    final now = _now();
    final points = await _numeric(type, now, now);
    return points.isEmpty ? null : points.first.$2;
  }

  /// Read in metres on both platforms.
  @override
  Future<double?> latestHeightCentimeters() async {
    final metres = await _latest(HealthDataType.HEIGHT);
    return metres == null ? null : metres * 100;
  }

  @override
  Future<double?> latestWeightKilograms() => _latest(HealthDataType.WEIGHT);

  /// The value of the sample that ended last, from any source, as Swift's
  /// onboarding reads it.
  Future<double?> _latest(HealthDataType type) async {
    final points = await _numeric(type, _ever, _now());
    if (points.isEmpty) return null;
    return points.reduce((a, b) => b.$1.dateTo.isAfter(a.$1.dateTo) ? b : a).$2;
  }

  Future<List<(HealthDataPoint, double)>> _numeric(
    HealthDataType type,
    DateTime start,
    DateTime end,
  ) async => [
    for (final point in await _health.getHealthDataFromTypes(
      types: [type],
      startTime: start,
      endTime: end,
    ))
      if (point.value case final NumericHealthValue value)
        (point, value.numericValue.toDouble()),
  ];

  @override
  Future<String?> writeWeight(double kilograms, DateTime date) async {
    final id = await _health.writeHealthDataUUID(
      value: kilograms,
      unit: HealthDataUnit.KILOGRAM,
      type: HealthDataType.WEIGHT,
      startTime: date,
    );
    // The package turns a missing id into the text "null".
    return id == null || id.isEmpty || id == 'null' ? null : id.toUpperCase();
  }

  @override
  Future<bool> writeStrengthWorkout({
    required DateTime start,
    required DateTime end,
    String? title,
  }) => _health.writeWorkoutData(
    activityType: _appleHealth
        ? HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING
        : HealthWorkoutActivityType.STRENGTH_TRAINING,
    start: start,
    end: end,
    title: title,
  );
}
