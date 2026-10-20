// Small builders for the models the expenditure inputs and the check-in flow
// read, in local time like the app's own data.
import 'package:compound_models/compound_models.dart';

/// Local midnight [daysAgo] days before [today].
DateTime dayBefore(DateTime today, int daysAgo) =>
    DateTime(today.year, today.month, today.day - daysAgo);

/// `YYYY-MM-DD` of [date] in local time.
String keyOf(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

var _ids = 0;

/// A meal of [calories] on [date]'s day, keyed [dayKey] when given.
MealLogModel meal(DateTime date, double? calories, {String? dayKey}) =>
    MealLogModel(
      mealId: 'meal-${_ids++}',
      authorId: 'user-1',
      dayKey: dayKey ?? keyOf(date),
      date: date,
      items: [
        MealItemModel(
          itemId: 'item-${_ids++}',
          sourceType: MealItemSourceType.ingredient,
          sourceId: 'source-1',
          displayName: 'Anything',
          amount: 100,
          unit: 'g',
          nutrients: NutrientMap({
            NutrientKey.protein: 10,
            NutrientKey.calories: ?calories,
          }),
        ),
      ],
    );

/// A weigh-in at [date].
BodyMeasurementEntry weighIn(
  DateTime date, {
  double? weightKg,
  double? bodyFat,
  bool deleted = false,
}) => BodyMeasurementEntry(
  id: 'entry-${_ids++}',
  authorId: 'user-1',
  date: date,
  source: WeightSource.manual,
  dateCreated: date,
  weightKg: weightKg,
  bodyFatPercentage: bodyFat,
  deletedAt: deleted ? date : null,
);

/// A day's step count.
StepsModel steps(DateTime date, int number, {bool deleted = false}) =>
    StepsModel(
      id: 'steps-${_ids++}',
      authorId: 'user-1',
      number: number,
      date: date,
      source: StepsSource.healthkit,
      dateCreated: date,
      dateModified: date,
      deletedAt: deleted ? date : null,
    );

/// An annotation on [dayKey].
NutritionDayAnnotation note(
  String dayKey, {
  bool partial = false,
  bool fasting = false,
}) => NutritionDayAnnotation(
  dayKey: dayKey,
  authorId: 'user-1',
  dateModified: DateTime.utc(2026),
  isPartiallyLogged: partial,
  isFastingDay: fasting,
);
