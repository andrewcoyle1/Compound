import 'dart:developer' as developer;

import 'package:body_repository/body_repository.dart';
import 'package:compound_models/compound_models.dart';
import 'package:health_repository/src/days.dart';
import 'package:health_repository/src/health_platform.dart';
import 'package:health_repository/src/health_scope.dart';
import 'package:health_repository/src/import_rules.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// Called when a Health read or write fails. Health is never essential, so
/// nothing is thrown at the caller: Swift's imports and export use `try?`.
typedef HealthErrorReporter = void Function(Object error, StackTrace stack);

/// Apple Health and Health Connect, as the Swift app uses Apple Health
/// (`HealthKitManager`, and the imports and exports in `StepsManager`,
/// `BodyMeasurementsManager`, `MealLogManager` and `HKWorkoutManager`).
///
/// Imports recount their whole window on every run and write only what
/// differs. Swift asks HealthKit only for what changed since a stored
/// anchor; the `health` package has no anchored queries on iOS. Because a
/// store without read access returns nothing rather than an error, a run
/// that reads nothing at all writes nothing, so revoking access never
/// empties the app.
class HealthRepository {
  /// Creates a [HealthRepository] over `platform`, writing imports through
  /// `body` and `nutrition`. Failures go to `onError`.
  new({
    required this._platform,
    required this._body,
    required this._nutrition,
    DateTime Function()? now,
    HealthErrorReporter? onError,
  }) : _now = now ?? DateTime.now,
       _onError = onError ?? _log;

  final HealthPlatform _platform;
  final BodyRepository _body;
  final NutritionRepository _nutrition;
  final DateTime Function() _now;
  final HealthErrorReporter _onError;

  final _running = <String>{};
  final _requested = <String>{};

  /// Whether Health can be used here (Swift `canRequestAuthorisation`).
  /// False when the platform cannot say.
  Future<bool> isAvailable() => _guard(_platform.isAvailable, false);

  /// Asks for [scope]'s access when Health is available. False when it is
  /// not, or the request failed or was refused.
  Future<bool> requestAuthorization(HealthScope scope) async =>
      await isAvailable() &&
      await _guard(() => _platform.requestAuthorization(scope), false);

  /// Whether saving workouts still needs the person's permission. False
  /// when Health is unavailable, as in Swift.
  Future<bool> needsWorkoutAuthorization() async =>
      await isAvailable() &&
      await _guard(_platform.needsWorkoutAuthorization, false);

  // Onboarding's "Fill from Apple Health": ask for the one type the step
  // needs, at the moment the person taps, then read it. Any failure,
  // including a refusal, comes back as null, so the step says nothing was
  // found and manual entry carries on.

  /// The date of birth Health holds (Apple Health only), or null.
  Future<DateTime?> readDateOfBirth() =>
      _fill(HealthScope.dateOfBirth, _platform.dateOfBirth);

  /// The biological sex Health holds (Apple Health only), or null.
  Future<Gender?> readSex() => _fill(HealthScope.sex, _platform.sex);

  /// The latest height in Health, in centimetres, or null.
  Future<double?> readLatestHeightCentimeters() =>
      _fill(HealthScope.height, _platform.latestHeightCentimeters);

  /// The latest weight in Health, in kilograms, or null.
  Future<double?> readLatestWeightKilograms() =>
      _fill(HealthScope.weight, _platform.latestWeightKilograms);

  Future<T?> _fill<T>(HealthScope scope, Future<T?> Function() read) async =>
      await requestAuthorization(scope) ? await _guard(read, null) : null;

  /// Saves [entry] with `BodyRepository.saveMeasurement`, first sending a
  /// weigh-in logged here to Health, so the entry is written once, with
  /// the sample's id in `healthkit_uuid`, which keeps a later save of the
  /// same entry from sending it again (`BodyMeasurementsManager
  /// .saveBodyMeasurement`). Access is asked for as weight is first logged,
  /// as Swift's `requestBodyMeasurementHealthAccess` does. A failed export
  /// still saves the entry.
  Future<void> saveMeasurement(BodyMeasurementEntry entry) async {
    final weightKg = entry.weightKg;
    if (weightKg == null ||
        entry.source == WeightSource.healthkit ||
        entry.healthKitUuid != null ||
        !await requestAuthorization(HealthScope.bodyMeasurements)) {
      return await _body.saveMeasurement(entry);
    }
    final id = await _guard(
      () => _platform.writeWeight(weightKg, entry.date),
      null,
    );
    final uuid = id == null ? null : healthUuid(id);
    await _body.saveMeasurement(
      uuid == null
          ? entry
          : BodyMeasurementEntry.fromFirestore({
              ...entry.toFirestore(),
              BodyMeasurementEntryKeys.healthKitUuid: uuid,
            }),
    );
  }

  /// Saves a finished [session] to Health as a strength training workout,
  /// as `HKWorkoutManager` ends its workout session. True when it was
  /// saved; false for a session that has not ended, or on failure. Access
  /// is the caller's to ask for, when the workout starts, as in Swift.
  ///
  /// Only the type and the time: Swift's live session also records heart
  /// rate and active energy from the device's sensors, which the `health`
  /// package cannot collect, and its pauses.
  Future<bool> exportWorkout(WorkoutSessionModel session) async {
    final endedAt = session.endedAt;
    if (endedAt == null) return false;
    return await _guard(
      () => _platform.writeStrengthWorkout(
        start: session.dateCreated,
        end: endedAt,
        title: session.name,
      ),
      false,
    );
  }

  /// Brings [uid]'s step history up to date with Health: one entry per day,
  /// holding the day's total (`StepsManager.importHealthKitChanges`). Steps
  /// before [since], usually the account's creation, are left out; a year
  /// back when null.
  Future<void> importSteps(String uid, {DateTime? since}) =>
      _serially('steps/$uid', () async {
        final (start, end) = await _window(since);
        final totals = await _platform.dailySteps(start, end);
        if (totals.isEmpty) return;
        final live = await _body.watchSteps(uid).first;
        final byDay = <DateTime, List<StepsModel>>{};
        for (final entry in live) {
          (byDay[startOfDay(entry.date)] ??= []).add(entry);
        }
        final days = {
          ...totals.keys,
          for (final entry in live)
            if (entry.source == StepsSource.healthkit &&
                !entry.date.isBefore(start))
              startOfDay(entry.date),
        }.toList()..sort();
        final now = _now();
        for (final day in days) {
          final entry = stepsEntryForDay(
            uid: uid,
            day: day,
            dayEntries: byDay[day] ?? const [],
            total: totals[day] ?? 0,
            now: now,
          );
          if (entry != null) await _body.saveSteps(entry);
        }
      });

  /// Brings [uid]'s weigh-ins up to date with Health: one entry per day at
  /// its lowest weigh-in, with that day's latest body fat
  /// (`BodyMeasurementsManager.importHealthKitChanges`). Swift reads all of
  /// Health's history; [since] narrows that.
  Future<void> importBodyMeasurements(String uid, {DateTime? since}) =>
      _serially('body/$uid', () async {
        final wanted = startOfDay(since ?? DateTime(1970));
        final start = startOfDay(await _platform.readableSince(wanted));
        final end = nextDay(startOfDay(_now()));
        final weights = await _platform.weights(start, end);
        // Body fat alone never makes an entry, so nothing read means no
        // access to weight: clearing then would empty the history.
        if (weights.isEmpty) return;
        final lowest = bestPerDay(weights, (a, b) => a.value < b.value);
        final latestFat = bestPerDay(
          await _platform.bodyFat(start, end),
          (a, b) => a.date.isAfter(b.date),
        );
        final live = await _body.watchMeasurements(uid).first;
        final byDay = <DateTime, List<BodyMeasurementEntry>>{};
        for (final entry in live) {
          (byDay[startOfDay(entry.date)] ??= []).add(entry);
        }
        final days = {
          ...lowest.keys,
          ...latestFat.keys,
          for (final entry in live)
            if (entry.source == WeightSource.healthkit &&
                !entry.date.isBefore(start))
              startOfDay(entry.date),
        }.toList()..sort();
        for (final day in days) {
          switch (bodyChangeForDay(
            uid: uid,
            day: day,
            dayEntries: byDay[day] ?? const [],
            weight: lowest[day],
            bodyFat: latestFat[day],
          )) {
            case SaveEntry(:final entry):
              await _body.saveMeasurement(entry);
            case ClearEntry(:final entryId):
              await _body.clearMeasurementFields(
                uid,
                entryId,
                ClearEntry.fields,
              );
            case null:
          }
        }
      });

  /// Brings [uid]'s Health import meals up to date: one per day holding the
  /// day's energy and macro totals, removed when the day empties
  /// (`MealLogManager.importHealthKitChanges`). An import hidden behind a
  /// meal logged here is kept current too, so it is right again if that
  /// meal is deleted; `NutritionRepository.watchMeals` does the hiding.
  /// Food before [since] is left out; a year back when null.
  Future<void> importNutrition(String uid, {DateTime? since}) =>
      _serially('nutrition/$uid', () async {
        final (start, end) = await _window(since);
        final totals = await _platform.dailyNutrition(start, end);
        if (totals.isEmpty) return;
        final imported = {
          for (final meal
              in await _nutrition
                  .watchMeals(uid, includeHiddenHealthImports: true)
                  .first)
            if (meal.isHealthKitImport) meal.mealId: meal,
        };
        final days = {
          ...totals.keys,
          for (final meal in imported.values)
            if (!meal.date.isBefore(start)) startOfDay(meal.date),
        }.toList()..sort();
        for (final day in days) {
          final id = MealLogModel.healthKitMealId(dayKeyOf(day));
          final existing = imported[id];
          final nutrients = totals[day] ?? const {};
          if (nutrients.isEmpty) {
            if (existing != null) await _nutrition.deleteMeal(uid, id);
          } else if (existing == null ||
              !_sameTotals(mealTotals(existing), nutrients)) {
            await _nutrition.saveMeal(
              healthMeal(uid: uid, day: day, nutrients: nutrients),
            );
          }
        }
      });

  bool _sameTotals(Map<NutrientKey, double> a, Map<NutrientKey, double> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  /// From the start of [since]'s day (a year back when null), or as far
  /// back as Health lets the app read, to the end of today.
  Future<(DateTime, DateTime)> _window(DateTime? since) async {
    final today = startOfDay(_now());
    final wanted = since == null
        ? DateTime(today.year - 1, today.month, today.day)
        : startOfDay(since);
    final start = startOfDay(await _platform.readableSince(wanted));
    return (start, nextDay(today));
  }

  /// One run of [key] at a time: a second would read the stored entries
  /// before the first's writes land. A request during a run is folded into
  /// one more run after it. A failed run is reported and writes nothing
  /// more.
  Future<void> _serially(String key, Future<void> Function() run) async {
    if (!_running.add(key)) {
      _requested.add(key);
      return;
    }
    try {
      do {
        _requested.remove(key);
        await _guard(run, null);
      } while (_requested.contains(key));
    } finally {
      _running.remove(key);
    }
  }

  Future<T> _guard<T>(Future<T> Function() action, T fallback) async {
    try {
      return await action();
    } on Object catch (error, stack) {
      _onError(error, stack);
      return fallback;
    }
  }

  static void _log(Object error, StackTrace stack) => developer.log(
    'A Health read or write failed',
    name: 'health_repository',
    error: error,
    stackTrace: stack,
  );
}
