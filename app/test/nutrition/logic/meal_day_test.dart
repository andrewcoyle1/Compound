import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// Mirrors the Swift `NutritionPresenterTests`, `MealHourHeaderPresenterTests`
/// and `CalendarDayMarker…Tests`.
void main() {
  // Monday 21 September 2026: the plan is indexed by weekday.
  final monday = DateTime(2026, 9, 21);
  const mondayKey = '2026-09-21';

  MealItemModel item(
    String id, {
    double calories = 100,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
  }) => MealItemModel(
    itemId: id,
    sourceType: MealItemSourceType.ingredient,
    sourceId: 'source-1',
    displayName: 'Food $id',
    amount: 100,
    unit: 'g',
    nutrients: NutrientMap({
      NutrientKey.calories: calories,
      NutrientKey.protein: protein,
      NutrientKey.carbs: carbs,
      NutrientKey.fatTotal: fat,
    }),
  );

  MealLogModel meal(
    String id, {
    int hour = 9,
    DateTime? day,
    double calories = 100,
    List<MealItemModel>? items,
  }) {
    final on = day ?? monday;
    return MealLogModel(
      mealId: id,
      authorId: 'author-1',
      dayKey: dayKeyOf(on),
      date: DateTime(on.year, on.month, on.day, hour, 30),
      items: items ?? [item('$id-item', calories: calories)],
    );
  }

  DailyMacroTarget target(double offset) => DailyMacroTarget(
    calories: 2000 + offset,
    proteinGrams: 100 + offset,
    carbGrams: 200 + offset,
    fatGrams: 50 + offset,
  );

  DietPlan plan(List<DailyMacroTarget> days) => DietPlan(
    planId: 'plan-1',
    createdAt: monday,
    tdeeEstimate: 2500,
    preferredDiet: 'balanced',
    calorieFloor: 'standard',
    trainingType: 'strength',
    calorieDistribution: 'even',
    proteinIntake: 'high',
    days: days,
  );

  final week = [for (var i = 0; i < 7; i++) target(i.toDouble())];

  FoodLogSettings settings({
    int startHour = 7,
    int endHour = 23,
    bool hideEmptyHours = false,
  }) => FoodLogSettings(
    authorId: 'author-1',
    startHour: startHour,
    endHour: endHour,
    hideEmptyHours: hideEmptyHours,
  );

  List<int> hoursOf(List<TimelineHour> timeline) => [
    for (final hour in timeline) hour.hour.hour,
  ];

  group('dailyTarget', () {
    test('each weekday reads its own target, Monday first', () {
      for (var offset = 0; offset < 7; offset++) {
        final day = DateTime(2026, 9, 21 + offset);
        expect(
          dailyTarget(plan(week), dayKeyOf(day))?.calories,
          2000 + offset,
          reason: 'day $offset after Monday',
        );
      }
    });

    test('no plan means no target', () {
      expect(dailyTarget(null, mondayKey), isNull);
    });

    test('a short plan does not overrun', () {
      expect(dailyTarget(plan(week.sublist(0, 2)), '2026-09-27'), isNull);
    });

    test('carries every macro', () {
      expect(dailyTarget(plan(week), mondayKey), (
        calories: 2000.0,
        proteinGrams: 100.0,
        carbGrams: 200.0,
        fatGrams: 50.0,
      ));
    });
  });

  group('totals', () {
    test('an item without a nutrient counts it as zero', () {
      const bare = MealItemModel(
        itemId: 'a',
        sourceType: MealItemSourceType.quickAdd,
        sourceId: 'quick_add',
        displayName: 'Water',
        amount: 1,
        unit: 'serving',
      );
      expect(bare.macros, (
        calories: 0.0,
        proteinGrams: 0.0,
        carbGrams: 0.0,
        fatGrams: 0.0,
      ));
    });

    test("sum each macro across the hour's meals", () {
      final meals = [
        meal(
          'm1',
          items: [
            item('a', calories: 300.6, protein: 15.2, carbs: 20.5, fat: 9.9),
          ],
        ),
        meal(
          'm2',
          items: [
            item('b', calories: 199.9, protein: 10.3, carbs: 21.9, fat: 4.6),
          ],
        ),
      ];
      final totals = totalsOf(meals);
      // The header cuts them to whole numbers: 500, 25, 42, 14.
      expect(Macro.calories.of(totals).truncate(), 500);
      expect(Macro.protein.of(totals).truncate(), 25);
      expect(Macro.carbs.of(totals).truncate(), 42);
      expect(Macro.fat.of(totals).truncate(), 14);
    });
  });

  group('mealsOnDay', () {
    test("leaves out another day's meals, and sorts by time", () {
      final yesterday = DateTime(2026, 9, 20);
      final meals = mealsOnDay([
        meal('late', hour: 20),
        meal('yesterday', day: yesterday),
        meal('early', hour: 8),
      ], mondayKey);
      expect([for (final m in meals) m.mealId], ['early', 'late']);
    });
  });

  group('timelineHours', () {
    test('spans the configured hours, ends included', () {
      final timeline = timelineHours(
        day: monday,
        meals: const [],
        settings: settings(startHour: 8, endHour: 11),
      );
      expect(hoursOf(timeline), [8, 9, 10, 11]);
    });

    test('a meal lands in its own hour', () {
      final timeline = timelineHours(
        day: monday,
        meals: [meal('m1')],
        settings: settings(startHour: 8, endHour: 11),
      );
      final nine = timeline.firstWhere((hour) => hour.hour.hour == 9);
      expect([for (final m in nine.meals) m.mealId], ['m1']);
      expect(timeline.where((hour) => hour.meals.isNotEmpty), hasLength(1));
    });

    test('meals in the same hour share a row', () {
      final timeline = timelineHours(
        day: monday,
        meals: [meal('m1'), meal('m2')],
        settings: settings(startHour: 8, endHour: 11),
      );
      expect(timeline.firstWhere((h) => h.hour.hour == 9).meals, hasLength(2));
    });

    test('hiding empty hours leaves only logged ones', () {
      final timeline = timelineHours(
        day: monday,
        meals: [meal('m1'), meal('m2', hour: 13)],
        settings: settings(startHour: 8, endHour: 20, hideEmptyHours: true),
      );
      expect(hoursOf(timeline), [9, 13]);
    });

    test('an inverted window produces no hours', () {
      final timeline = timelineHours(
        day: monday,
        meals: const [],
        settings: settings(startHour: 20, endHour: 8),
      );
      expect(timeline, isEmpty);
    });

    test('a meal outside the window is still shown, first', () {
      final timeline = timelineHours(
        day: monday,
        meals: [meal('snack', hour: 2)],
        settings: settings(),
      );
      expect(timeline.first.hour, DateTime(2026, 9, 21, 2));
      expect([for (final m in timeline.first.meals) m.mealId], ['snack']);
    });

    test('hiding empty hours still shows an out-of-window meal', () {
      final timeline = timelineHours(
        day: monday,
        meals: [meal('snack', hour: 2), meal('lunch', hour: 13)],
        settings: settings(hideEmptyHours: true),
      );
      expect(hoursOf(timeline), [2, 13]);
    });

    test('empty hours outside the window are not drawn', () {
      final timeline = timelineHours(
        day: monday,
        meals: [meal('snack', hour: 2)],
        settings: settings(startHour: 8, endHour: 10),
      );
      expect(hoursOf(timeline), [2, 8, 9, 10]);
    });

    test('groups a UTC timestamp by its local hour', () {
      final at = DateTime(2026, 9, 21, 9, 15);
      final timeline = timelineHours(
        day: monday,
        meals: [
          MealLogModel(
            mealId: 'utc',
            authorId: 'author-1',
            dayKey: mondayKey,
            date: at.toUtc(),
            items: const [],
          ),
        ],
        settings: settings(hideEmptyHours: true),
      );
      expect(timeline.single.hour, DateTime(2026, 9, 21, 9));
    });
  });

  group('itemTimestamp', () {
    test('only the first item in a meal carries a time', () {
      final logged = meal('m1', items: [item('a'), item('a2'), item('b')]);
      expect(itemTimestamp(logged.items[0], logged), logged.date);
      expect(itemTimestamp(logged.items[2], logged), isNull);
    });

    test('compares ids, so an equal second helping has no time', () {
      final helping = item('a');
      final logged = meal('m1', items: [helping, item('b')]);
      expect(itemTimestamp(item('b'), logged), isNull);
      expect(itemTimestamp(helping, meal('m2', items: const [])), isNull);
    });
  });

  group(CalorieMarker, () {
    test('a day with a goal is marked with progress', () {
      final markers = calorieMarkersByDay([
        meal('m1', calories: 500),
        meal('m2', hour: 13, calories: 300),
      ], plan(List.filled(7, target(0))));
      expect(markers, {
        mondayKey: const CalorieMarker(calories: 800, goal: 2000),
      });
      expect(markers[mondayKey]!.fraction, 0.4);
    });

    test('a day without a goal falls back to a plain mark', () {
      final markers = calorieMarkersByDay([meal('m1', calories: 500)], null);
      expect(markers[mondayKey], const CalorieMarker(calories: 500));
      expect(markers[mondayKey]!.fraction, 1);
      expect(markers[mondayKey]!.isEmpty, isFalse);
    });

    test('a zero calorie goal falls back to a plain mark', () {
      const zero = DailyMacroTarget(
        calories: 0,
        proteinGrams: 0,
        carbGrams: 0,
        fatGrams: 0,
      );
      final markers = calorieMarkersByDay([
        meal('m1'),
      ], plan(List.filled(7, zero)));
      expect(markers[mondayKey]!.goal, isNull);
    });

    test('unlogged days carry no marker', () {
      expect(calorieMarkersByDay([meal('m1')], null), hasLength(1));
    });

    test('met, within grace and over goal', () {
      const met = CalorieMarker(calories: 2250, goal: 2200);
      const withinGrace = CalorieMarker(calories: 2290, goal: 2200);
      const over = CalorieMarker(calories: 2650, goal: 2200);
      const half = CalorieMarker(calories: 1100, goal: 2200);
      expect(met.isGoalMet, isTrue);
      expect(met.isOverGoal, isFalse);
      expect(withinGrace.isOverGoal, isFalse);
      expect(over.isOverGoal, isTrue);
      expect(over.fraction, 1);
      expect(half.isGoalMet, isFalse);
      expect(half.fraction, 0.5);
      expect(const CalorieMarker(calories: 900).isGoalMet, isFalse);
      expect(const CalorieMarker(calories: 900).isOverGoal, isFalse);
    });

    test('a day with a goal and nothing toward it is empty', () {
      expect(const CalorieMarker(calories: 0, goal: 2200).isEmpty, isTrue);
    });
  });

  group('dayKeyOf and startOfDay', () {
    test('pad and drop the time', () {
      expect(dayKeyOf(DateTime(987, 3, 4)), '0987-03-04');
      expect(startOfDay(DateTime(2026, 9, 21, 13, 5)), monday);
    });
  });
}
