import 'package:body_repository/body_repository.dart';
import 'package:compound/progress/logic/progress_overview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../../helpers/helpers.dart';

/// The pure parts of Swift `AnalyticsPresenterTests`, `HabitsPresenterTests`
/// and `AnalyticsInsightsPresenterTests`: what each card is built from,
/// and that an empty card reads as absent rather than zero.
void main() {
  // Thursday 15 October 2026, 7pm.
  final now = DateTime(2026, 10, 15, 19);
  DateTime daysAgo(int days) => DateTime(2026, 10, 15 - days, 12);

  BodyMeasurementEntry weighIn(
    String id,
    int ago, {
    double? weightKg = 72,
    double? bodyFat,
    bool deleted = false,
  }) => BodyMeasurementEntry(
    id: id,
    authorId: 'me',
    weightKg: weightKg,
    bodyFatPercentage: bodyFat,
    date: daysAgo(ago),
    source: WeightSource.manual,
    dateCreated: daysAgo(ago),
    deletedAt: deleted ? now : null,
  );

  StepsModel steps(int number, int ago, {String? id, bool deleted = false}) =>
      StepsModel(
        id: id ?? 'steps-$ago-$number',
        authorId: 'me',
        number: number,
        date: daysAgo(ago),
        source: StepsSource.healthkit,
        dateCreated: daysAgo(ago),
        dateModified: daysAgo(ago),
        deletedAt: deleted ? now : null,
      );

  WeightGoal goal({required int setDaysAgo}) => WeightGoal(
    goalId: 'goal',
    userId: 'me',
    objective: OverarchingObjective.loseWeight,
    startingWeightKg: 80,
    targetWeightKg: 70,
    weeklyChangeKg: 0.5,
    createdAt: daysAgo(setDaysAgo),
    status: GoalStatus.active,
  );

  MealLogModel meal(int ago, {double calories = 2100, double protein = 150}) =>
      MealLogModel(
        mealId: 'meal-$ago-$calories',
        authorId: 'me',
        dayKey: daysAgo(ago).toIso8601String().substring(0, 10),
        date: daysAgo(ago),
        items: [
          MealItemModel(
            itemId: 'item-$ago',
            sourceType: MealItemSourceType.ingredient,
            sourceId: 'food',
            displayName: 'Food',
            amount: 100,
            unit: 'g',
            nutrients: NutrientMap({
              NutrientKey.calories: calories,
              NutrientKey.protein: protein,
            }),
          ),
        ],
      );

  group(ProgressSection, () {
    AnalyticsSettings hiding(List<ProgressSection> sections) =>
        AnalyticsSettings(
          authorId: 'me',
          hiddenSectionIds: [for (final s in sections) s.id],
        );

    test('every section is visible by default', () {
      for (final section in ProgressSection.values) {
        expect(section.isVisible(null), isTrue);
        expect(section.isVisible(hiding(const [])), isTrue);
      }
    });

    test('a hidden section is not visible', () {
      final settings = hiding([ProgressSection.habits]);
      expect(ProgressSection.habits.isVisible(settings), isFalse);
      expect(ProgressSection.nutrition.isVisible(settings), isTrue);
    });

    test('ids are the Swift raw values, in the tab order', () {
      expect(
        [for (final s in ProgressSection.values) s.id],
        [
          'insights_and_analytics',
          'habits',
          'nutrition',
          'body_metrics',
          'muscle_groups',
          'exercises',
        ],
      );
    });
  });

  group('habitGrid', () {
    test('is always thirty cells', () {
      expect(habitGrid(const [], now), hasLength(30));
      expect(habitGrid(const [], now).every((d) => !d), isTrue);
      expect(habitGrid([for (var i = 0; i < 40; i++) daysAgo(i)], now), [
        for (var i = 0; i < 30; i++) true,
      ]);
    });

    test('today fills the last cell', () {
      final grid = habitGrid([daysAgo(0)], now);
      expect(grid.last, isTrue);
      expect(grid.take(29).every((d) => !d), isTrue);
    });

    test('29 days ago fills the first cell; 30 is off the grid', () {
      expect(habitGrid([daysAgo(29)], now).first, isTrue);
      expect(habitGrid([daysAgo(30)], now).every((d) => !d), isTrue);
    });

    test('twice in a day fills one cell', () {
      final grid = habitGrid([daysAgo(1), daysAgo(1)], now);
      expect(grid.where((d) => d), hasLength(1));
    });
  });

  group('countThisWeek', () {
    test('counts every entry from the week start through today', () {
      // The week from Monday 12 October.
      final dates = [
        daysAgo(0),
        daysAgo(1),
        daysAgo(1),
        daysAgo(3),
        daysAgo(4),
        DateTime(2026, 10, 16, 8),
      ];
      expect(countThisWeek(dates, now, firstWeekday: DateTime.monday), 4);
      // From Sunday 11 October, the 11th counts too.
      expect(countThisWeek(dates, now, firstWeekday: DateTime.sunday), 5);
    });

    test('no entries count as none', () {
      expect(countThisWeek(const [], now, firstWeekday: DateTime.monday), 0);
    });
  });

  group('weighInDates', () {
    test('entries without a weight and deleted ones are not weigh-ins', () {
      expect(
        weighInDates([
          weighIn('waist', 0, weightKg: null),
          weighIn('gone', 1, deleted: true),
          weighIn('real', 2),
        ]),
        [daysAgo(2)],
      );
    });
  });

  group('lastWorkouts', () {
    test('keeps the seven most recent, oldest first', () {
      final sessions = [
        for (var day = 1; day <= 9; day++) fixtureSession('s$day', day: day),
      ]..shuffle();
      final last = lastWorkouts(sessions);
      expect(
        [for (final s in last) s.id],
        [for (var day = 3; day <= 9; day++) 's$day'],
      );
    });

    test('fewer than seven are all kept', () {
      expect(lastWorkouts([fixtureSession('one')]), hasLength(1));
    });
  });

  group('lastBodyFatReadings', () {
    test('is its own series, oldest first, the last seven', () {
      final readings = lastBodyFatReadings([
        weighIn('no-fat', 1),
        weighIn('gone', 2, bodyFat: 30, deleted: true),
        for (var i = 3; i < 12; i++) weighIn('f$i', i, bodyFat: 20.0 + i),
      ]);
      expect(
        [for (final r in readings) r.bodyFatPercentage],
        [for (var i = 9; i >= 3; i--) 20.0 + i],
      );
    });
  });

  group('lastReadings', () {
    test('keeps only the last seven', () {
      expect(lastReadings([for (var i = 0; i < 10; i++) i]), [
        for (var i = 3; i < 10; i++) i,
      ]);
    });
  });

  group('stepsLastWeek', () {
    test('shows the last seven days, oldest first', () {
      final week = stepsLastWeek([
        for (var i = 0; i < 3; i++) steps(8000 + i, i),
      ], now);
      expect([for (final s in week) s.number], [8002, 8001, 8000]);
    });

    test("today's steps are shown", () {
      expect(stepsLastWeek([steps(9000, 0)], now).single.number, 9000);
    });

    test('two readings for one day keep the higher', () {
      final week = stepsLastWeek([
        steps(4000, 1, id: 'partial'),
        steps(9000, 1, id: 'complete'),
        steps(3000, 1, id: 'later partial'),
      ], now);
      expect([for (final s in week) s.number], [9000]);
    });

    test('steps older than a week and deleted ones are left out', () {
      final week = stepsLastWeek([
        steps(8000, 30),
        steps(8500, 7),
        steps(7000, 2, deleted: true),
        steps(9000, 1),
      ], now);
      expect([for (final s in week) s.number], [9000]);
    });
  });

  group('macrosLastWeek', () {
    test('is seven days, oldest first, unlogged days zero', () {
      final week = macrosLastWeek([meal(0), meal(6, calories: 1800)], now);
      expect(week, hasLength(7));
      expect(week.first.calories, 1800);
      expect(week.last.calories, 2100);
      expect(week[3].calories, 0);
    });

    test('a meal older than the week is left out', () {
      final week = macrosLastWeek([meal(7)], now);
      expect(week.every((day) => day.calories == 0), isTrue);
    });
  });

  group('proteinCeiling', () {
    test('has a ceiling without a target', () {
      expect(proteinCeiling(eaten: 0, target: null), 180);
    });

    test('stretches past the target to what was eaten', () {
      expect(proteinCeiling(eaten: 150, target: 100), 150);
      expect(proteinCeiling(eaten: 50, target: 100), 120);
    });
  });

  group('goalFraction', () {
    test('halfway to the target is half', () {
      expect(goalFraction(goal(setDaysAgo: 10), 75), 0.5);
    });

    test('an overshot goal is complete', () {
      expect(goalFraction(goal(setDaysAgo: 10), 65), 1);
    });

    test('moving the wrong way is no progress', () {
      expect(goalFraction(goal(setDaysAgo: 10), 85), 0);
      expect(goalFraction(goal(setDaysAgo: 10), 80), 0);
    });

    test('gaining counts upward', () {
      final gain = WeightGoal(
        goalId: 'gain',
        userId: 'me',
        objective: OverarchingObjective.gainWeight,
        startingWeightKg: 60,
        targetWeightKg: 64,
        weeklyChangeKg: 0.25,
        createdAt: daysAgo(10),
        status: GoalStatus.active,
      );
      expect(goalFraction(gain, 61), 0.25);
      expect(goalFraction(gain, 59), 0);
    });

    test('a goal with no distance has no progress', () {
      final flat = WeightGoal(
        goalId: 'flat',
        userId: 'me',
        objective: OverarchingObjective.maintain,
        startingWeightKg: 70,
        targetWeightKg: 70,
        weeklyChangeKg: 0,
        createdAt: daysAgo(10),
        status: GoalStatus.active,
      );
      expect(goalFraction(flat, 69), 0);
    });
  });

  group('progressTowardGoal', () {
    test('without a goal there is no progress to show', () {
      expect(progressTowardGoal(null, [weighIn('w', 1)]), (
        state: GoalProgressState.noGoal,
        percent: 0.0,
      ));
    });

    test('a goal with no weigh-ins since it was set shows nothing', () {
      expect(
        progressTowardGoal(goal(setDaysAgo: 1), [
          weighIn('w', 5, weightKg: 80),
        ]),
        (state: GoalProgressState.noEntries, percent: 0.0),
      );
    });

    test('halfway to the target is half the bar', () {
      expect(
        progressTowardGoal(goal(setDaysAgo: 10), [
          weighIn('w', 1, weightKg: 75),
        ]),
        (state: GoalProgressState.measured, percent: 50.0),
      );
    });

    test('progress is clamped to the bar', () {
      expect(
        progressTowardGoal(goal(setDaysAgo: 10), [
          weighIn('w', 1, weightKg: 65),
        ]).percent,
        100,
      );
      expect(
        progressTowardGoal(goal(setDaysAgo: 10), [
          weighIn('w', 1, weightKg: 85),
        ]).percent,
        0,
      );
    });

    test('progress is measured from the trend weight', () {
      // A steady 76 kg, then one morning's 74: the trend barely moves, so
      // progress stays near 40% rather than jumping to 60%.
      final percent = progressTowardGoal(goal(setDaysAgo: 20), [
        for (var d = 15; d >= 1; d--) weighIn('e$d', d, weightKg: 76),
        weighIn('spike', 0, weightKg: 74),
      ]).percent;
      expect(percent, greaterThan(40));
      expect(percent, lessThan(50));
    });
  });
}
