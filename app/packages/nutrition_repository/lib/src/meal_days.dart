import 'package:compound_models/compound_models.dart';

/// The meals the app counts (Swift `MealLogManager.userMeals`). Compound's
/// own log wins: on a day with any meal logged in Compound, that day's
/// Apple Health import is left out, so the same food is not counted twice.
/// A day with only the import keeps it.
List<MealLogModel> withoutDuplicateHealthImports(Iterable<MealLogModel> meals) {
  final loggedDays = {
    for (final meal in meals)
      if (!meal.isHealthKitImport) meal.dayKey,
  };
  return [
    for (final meal in meals)
      if (!meal.isHealthKitImport || !loggedDays.contains(meal.dayKey)) meal,
  ];
}

/// [meals] grouped by `day_key`: the days in ascending order, and each
/// day's meals in the order they were eaten.
Map<String, List<MealLogModel>> mealsByDay(Iterable<MealLogModel> meals) {
  final sorted = [...meals]
    ..sort(
      (a, b) => switch (a.dayKey.compareTo(b.dayKey)) {
        0 => a.date.compareTo(b.date),
        final order => order,
      },
    );
  final days = <String, List<MealLogModel>>{};
  for (final meal in sorted) {
    (days[meal.dayKey] ??= []).add(meal);
  }
  return days;
}
