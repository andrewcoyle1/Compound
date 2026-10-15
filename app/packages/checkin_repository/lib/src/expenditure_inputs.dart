/// The expenditure engine's inputs, assembled from the repositories' data
/// the way the Swift `CoreInteractor+Expenditure.swift` and
/// `ExpenditureSampleBuilder.swift` assemble them.
library;

import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:compound_models/compound_models.dart';

/// [date]'s calendar day in local time, as `YYYY-MM-DD` (Swift
/// `Date.dayKey`).
String localDayKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

/// Local midnight at the start of [dayKey] (Swift `Date(dayKey:)`).
DateTime localMidnight(String dayKey) {
  final [year, month, day] = dayKey.split('-').map(int.parse).toList();
  return DateTime(year, month, day);
}

final _dayKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// [dayKey] when it names a real day, else null (Swift's `Date(dayKey:)`
/// failing).
String? _validDayKey(String dayKey) =>
    _dayKeyPattern.hasMatch(dayKey) &&
        localDayKey(localMidnight(dayKey)) == dayKey
    ? dayKey
    : null;

bool _isLocalMidnight(DateTime date) {
  final local = date.toLocal();
  return local == DateTime(local.year, local.month, local.day);
}

/// Everything `CoreInteractor` reads to estimate expenditure and decide
/// whether the check-in is due, at [now].
///
/// Pass the repositories' current data: [meals] as `watchMeals` emits them
/// (Apple Health duplicates already dropped), and [measurements] and [steps]
/// with or without their deleted entries, which are ignored here either way.
class const ExpenditureInputs({
  /// The moment the estimate is for (Swift `Date()`).
  required final DateTime now,

  /// The user's strategy settings.
  required final NutritionStrategySettings settings,

  /// The user, for the formula prior; null reads as Swift's defaults.
  final UserModel? user,
  final List<MealLogModel> meals = const [],
  final List<BodyMeasurementEntry> measurements = const [],
  final List<StepsModel> steps = const [],
  final List<NutritionDayAnnotation> annotations = const [],
  final LoggingBreak? loggingBreak,
  final CheckInRecord? checkInRecord,
}) {
  /// Creates the inputs.
  this;

  /// The break when it is open at [now] (`openLoggingBreak`).
  LoggingBreak? get openLoggingBreak {
    final current = loggingBreak;
    return current != null && current.isOpenAt(now) ? current : null;
  }

  /// The day the estimate is for: the day an open break began, else [now]'s
  /// (`expenditureToday`, `CoreInteractor+Expenditure.swift:70-72`).
  String get today => localDayKey(openLoggingBreak?.startDate ?? now);

  /// One sample per day up to yesterday (`expenditureSamples`,
  /// `ExpenditureSampleBuilder.samples`). A meal's day is its `day_key`, or
  /// its date's when the key is not a day; the break covers the days that
  /// begin inside it.
  List<maths.DailySample> get samples {
    final current = loggingBreak;
    final breakDays = current == null
        ? null
        : (
            startDay: _isLocalMidnight(current.startDate)
                ? localDayKey(current.startDate)
                : maths.addDays(localDayKey(current.startDate), 1),
            endDay: switch (current.endDate) {
              final end? => localDayKey(end),
              null => null,
            },
          );
    return maths.expenditureSamples(
      today: today,
      meals: [
        for (final meal in meals)
          (
            dayKey: _validDayKey(meal.dayKey) ?? localDayKey(meal.date),
            calories: meal.items.fold(
              0,
              (sum, item) =>
                  sum + (item.nutrients.values[NutrientKey.calories] ?? 0),
            ),
          ),
      ],
      measurements: [
        for (final entry in measurements)
          maths.WeighIn(
            day: localDayKey(entry.date),
            weightKg: entry.weightKg,
            deleted: entry.deletedAt != null,
            at: entry.date,
          ),
      ],
      steps: [
        for (final record in steps)
          maths.StepRecord(
            day: localDayKey(record.date),
            number: record.number,
            deleted: record.deletedAt != null,
          ),
      ],
      annotations: [
        for (final annotation in annotations)
          if (_validDayKey(annotation.dayKey) case final dayKey?)
            maths.DayAnnotation(
              dayKey: dayKey,
              isPartiallyLogged: annotation.isPartiallyLogged,
              isFastingDay: annotation.isFastingDay,
            ),
      ],
      loggingBreak: breakDays,
    );
  }

  /// The settings the engine reads.
  maths.ExpenditureSettings get engineSettings => maths.ExpenditureSettings(
    calculationMode: switch (settings.calculationMode) {
      ExpenditureCalculationMode.dynamic =>
        maths.ExpenditureCalculationMode.dynamic,
      ExpenditureCalculationMode.fixed =>
        maths.ExpenditureCalculationMode.fixed,
    },
    calculationStartDay: switch (settings.calculationStartDate) {
      final start? => localDayKey(start),
      null => null,
    },
    stepInformedUpdates: settings.stepInformedUpdates,
  );

  Iterable<BodyMeasurementEntry> get _live =>
      measurements.where((entry) => entry.deletedAt == null);

  /// The latest of [entries] by date; of two on the same instant, the first
  /// listed, as Swift's `max(by:)` keeps.
  static BodyMeasurementEntry? _latest(Iterable<BodyMeasurementEntry> entries) {
    BodyMeasurementEntry? latest;
    for (final entry in entries) {
      if (latest == null || entry.date.isAfter(latest.date)) latest = entry;
    }
    return latest;
  }

  /// The formula expenditure the engine starts from
  /// (`CoreInteractor.estimateTDEE(user:)`, `NutritionManager.swift:290-314`):
  /// the settings' equation, resolved against the latest logged body fat.
  double get priorKcal {
    final bodyFat = _latest(
      _live.where((entry) => entry.bodyFatPercentage != null),
    )?.bodyFatPercentage;
    final dob = user?.submittedDateOfBirth;
    return maths.estimateTdee(
      gender: maths.Gender.tryParse(user?.submittedGender?.value),
      weightKg: user?.submittedWeightKilograms,
      heightCm: user?.submittedHeightCentimeters,
      ageYears: dob == null ? null : _age(dob),
      activity: maths.ActivityLevel.tryParse(
        user?.submittedDailyActivityLevel?.value,
      ),
      equation: maths.resolvedBmrEquation(
        equation: maths.BmrEquation.tryParse(settings.bmrEquation.value)!,
        method: switch (settings.estimationMethod) {
          ExpenditureEstimationMethod.standard =>
            maths.ExpenditureEstimationMethod.standard,
          ExpenditureEstimationMethod.bodyFatAware =>
            maths.ExpenditureEstimationMethod.bodyFatAware,
        },
        bodyFatPercentage: bodyFat,
      ),
      bodyFatPercentage: bodyFat,
    );
  }

  /// Whole years from [dob] to [now] in local time, never under 14
  /// (`NutritionManager.calculateAge`).
  int _age(DateTime dob) {
    final birth = dob.toLocal();
    final at = now.toLocal();
    var years = at.year - birth.year;
    final birthday = DateTime(
      at.year,
      birth.month,
      birth.day,
      birth.hour,
      birth.minute,
      birth.second,
      birth.millisecond,
    );
    if (birthday.isAfter(at)) years--;
    return years < 14 ? 14 : years;
  }

  /// How old a body fat reading may be and still set [kcalPerKg]
  /// (`CoreInteractor.trustedBodyFatDays`).
  static const trustedBodyFatDays = 90;

  /// The energy in a kilogram of this user's weight change
  /// (`expenditureKcalPerKg`, `CoreInteractor+Expenditure.swift:47-59`): the
  /// latest weight with a body fat reading from the last 90 days, else
  /// 7,700.
  double get kcalPerKg {
    final at = now.toLocal();
    final cutoff = DateTime(
      at.year,
      at.month,
      at.day - trustedBodyFatDays,
      at.hour,
      at.minute,
      at.second,
      at.millisecond,
      at.microsecond,
    );
    final bodyFat = _latest(
      _live.where(
        (entry) =>
            !entry.date.isBefore(cutoff) && (entry.bodyFatPercentage ?? 0) > 0,
      ),
    )?.bodyFatPercentage;
    final weight =
        _latest(_live.where((entry) => (entry.weightKg ?? 0) > 0))?.weightKg ??
        user?.submittedWeightKilograms;
    return maths.energyDensityKcalPerKg(weight, bodyFat);
  }

  /// One estimate per day through [today] (`expenditureHistory`).
  List<maths.ExpenditureEstimate> get history => maths.expenditureHistory(
    samples: samples,
    priorKcal: priorKcal,
    today: today,
    settings: engineSettings,
    kcalPerKg: kcalPerKg,
  );

  /// Today's estimate (`currentExpenditure`): the last of [history].
  maths.ExpenditureEstimate get current => history.last;

  /// Whether the check-in is waiting (`checkInState`,
  /// `CheckInSchedule.state`). An open break holds it from the moment it
  /// began.
  maths.CheckInState get checkInState {
    if (openLoggingBreak != null) return maths.CheckInState.inBreak;
    return maths.checkInState(
      today: localDayKey(now),
      checkInWeekday: settings.checkInWeekday,
      lastCompletedWeekStart: switch (checkInRecord?.lastCompletedWeekStart) {
        final week? => localDayKey(week),
        null => null,
      },
      lastSkippedWeekStart: switch (checkInRecord?.lastSkippedWeekStart) {
        final week? => localDayKey(week),
        null => null,
      },
    );
  }

  /// Local midnight on the Monday starting [now]'s week: the `weekStart` a
  /// due check-in is for, and what completing or skipping it records
  /// (`CheckInSchedule.weekStart`).
  DateTime get checkInWeekStart =>
      localMidnight(maths.checkInWeekStart(localDayKey(now)));
}
