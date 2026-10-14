/// One sample per day for the expenditure engine
/// (`ExpenditureSampleBuilder.swift`, `DailySample` in
/// `ExpenditureModels.swift`).
library;

import 'package:compound_maths/src/day_key.dart';

/// One calendar day as the engine reads it (`DailySample`).
class const DailySample({
  required final String day,
  final double? intakeKcal,
  final double? weightKg,
  final int? steps,
  final bool isExcluded = false,
  final bool isFastingDay = false,
});

/// One meal log's calories on its day.
typedef MealCalories = ({String dayKey, double calories});

/// One weigh-in. [at] orders two on the same day (a missing one sorts first); a
/// tie keeps the entry listed first.
class const WeighIn({
  required final String day,
  final double? weightKg,
  final bool deleted = false,
  final DateTime? at,
});

/// One day's step record.
class const StepRecord({
  required final String day,
  required final int number,
  final bool deleted = false,
});

/// The user's note on a day (`NutritionDayAnnotation`).
class const DayAnnotation({
  required final String dayKey,
  final bool isPartiallyLogged = false,
  final bool isFastingDay = false,
});

/// A break from logging (`LoggingBreak`): `startDay` is the first whole day
/// inside it, and `endDay` the last, or `null` while it is open.
typedef LoggingBreak = ({String startDay, String? endDay});

/// One sample per day from the first day with any data to yesterday
/// (`ExpenditureSampleBuilder.samples`). Today is never a sample.
///
/// A day with meal logs is logged even at zero calories; a fasting day with
/// none reads as zero. The first weigh-in of a day is its reading; of two step
/// records the larger wins. A partly logged day, or one inside the
/// [loggingBreak], is excluded.
List<DailySample> expenditureSamples({
  required String today,
  List<MealCalories> meals = const [],
  List<WeighIn> measurements = const [],
  List<StepRecord> steps = const [],
  List<DayAnnotation> annotations = const [],
  LoggingBreak? loggingBreak,
}) {
  final intake = <String, double>{};
  for (final meal in meals) {
    intake[meal.dayKey] = (intake[meal.dayKey] ?? 0) + meal.calories;
  }

  final earliest = <String, ({int at, double weightKg})>{};
  for (final entry in measurements) {
    final weight = entry.weightKg;
    if (entry.deleted || weight == null || !weight.isFinite || weight <= 0) {
      continue;
    }
    final at = entry.at?.microsecondsSinceEpoch ?? 0;
    final current = earliest[entry.day];
    if (current != null && current.at <= at) continue;
    earliest[entry.day] = (at: at, weightKg: weight);
  }

  final stepCounts = <String, int>{};
  for (final record in steps) {
    if (record.deleted) continue;
    final current = stepCounts[record.day] ?? 0;
    stepCounts[record.day] = record.number > current ? record.number : current;
  }
  final annotationByDay = {for (final a in annotations) a.dayKey: a};

  final days = {
    ...intake.keys,
    ...earliest.keys,
    ...stepCounts.keys,
  }.where((d) => d.compareTo(today) < 0).toList()..sort();
  if (days.isEmpty) return [];

  bool inBreak(String day) {
    final b = loggingBreak;
    if (b == null || day.compareTo(b.startDay) < 0) return false;
    final end = b.endDay;
    return end == null || day.compareTo(end) <= 0;
  }

  return [
    for (var day = days.first; day.compareTo(today) < 0; day = addDays(day, 1))
      () {
        final annotation = annotationByDay[day];
        final isFasting = annotation?.isFastingDay ?? false;
        return DailySample(
          day: day,
          intakeKcal: isFasting && intake[day] == null ? 0 : intake[day],
          weightKg: earliest[day]?.weightKg,
          steps: stepCounts[day],
          isExcluded: (annotation?.isPartiallyLogged ?? false) || inBreak(day),
          isFastingDay: isFasting,
        );
      }(),
  ];
}
