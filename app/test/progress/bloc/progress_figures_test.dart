// StepsPresenterTests, GoalProgressPresenterTests, the week and record
// cases of AnalyticsNutritionTargetChartTests and ProgressCarouselPresenter,
// and HabitsPresenterTests' food logging, on the figures behind the
// Progress tab's screens.
import 'package:app_ui/app_ui.dart' show AppWeightUnit;
import 'package:compound/progress/bloc/progress_figures.dart';
import 'package:compound/progress/logic/body_metrics.dart';
import 'package:compound/progress/logic/progress_carousel.dart';
import 'package:compound/progress/progress.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_repository/user_repository.dart' show sampleUser;

import '../../helpers/helpers.dart';

void main() {
  const uid = 'me';
  // Saturday 14 March 2026, 6pm: the week from Monday is 9–15 March.
  final now = DateTime(2026, 3, 14, 18);

  ProgressState state({
    List<BodyMeasurementEntry> measurements = const [],
    List<StepsModel> steps = const [],
    List<MealLogModel> meals = const [],
    List<WorkoutSessionModel> sessions = const [],
    DietPlan? dietPlan,
    WeightGoal? goal,
    UserModel? user,
    NutritionStrategySettings? strategySettings,
  }) => ProgressState(
    uid: uid,
    now: now,
    firstWeekday: DateTime.monday,
    measurements: measurements,
    steps: steps,
    meals: meals,
    sessions: sessions,
    dietPlan: dietPlan,
    goal: goal,
    user: user,
    strategySettings: strategySettings,
  );

  StepsModel reading(
    String id,
    int number,
    DateTime date, {
    String author = uid,
    DateTime? deletedAt,
  }) => StepsModel(
    id: id,
    authorId: author,
    number: number,
    date: date,
    source: StepsSource.healthkit,
    dateCreated: date,
    dateModified: date,
    deletedAt: deletedAt,
  );

  BodyMeasurementEntry weighIn(
    String id,
    DateTime date, {
    double? kg,
    double? waist,
    DateTime? deletedAt,
  }) => BodyMeasurementEntry(
    id: id,
    authorId: uid,
    weightKg: kg,
    waistCircumference: waist,
    date: date,
    source: WeightSource.manual,
    dateCreated: date,
    deletedAt: deletedAt,
  );

  MealLogModel meal(String dayKey, {double calories = 500}) => MealLogModel(
    mealId: 'meal-$dayKey',
    authorId: uid,
    dayKey: dayKey,
    date: DateTime.parse('${dayKey}T12:00:00'),
    items: [
      MealItemModel(
        itemId: 'item-$dayKey',
        sourceType: MealItemSourceType.ingredient,
        sourceId: 'food',
        displayName: 'Food',
        amount: 100,
        unit: 'g',
        nutrients: NutrientMap({
          NutrientKey.calories: calories,
          NutrientKey.protein: 40,
          NutrientKey.ironMg: 3,
        }),
      ),
    ],
  );

  DietPlan plan(List<double> calories) => DietPlan(
    planId: 'plan',
    createdAt: DateTime(2026, 3),
    tdeeEstimate: 2500,
    preferredDiet: 'balanced',
    calorieFloor: 'standard',
    trainingType: 'strength',
    calorieDistribution: 'even',
    proteinIntake: 'high',
    days: [
      for (final kcal in calories)
        DailyMacroTarget(
          calories: kcal,
          proteinGrams: 150,
          carbGrams: 200,
          fatGrams: 60,
        ),
    ],
  );

  final goal = WeightGoal(
    goalId: uid,
    userId: uid,
    objective: OverarchingObjective.loseWeight,
    startingWeightKg: 82,
    targetWeightKg: 78,
    weeklyChangeKg: 0.5,
    createdAt: DateTime(2026, 3, 5),
    status: GoalStatus.active,
  );

  group('steps', () {
    test('a day keeps its largest reading', () {
      final steps = state(
        steps: [
          reading('a', 4000, DateTime(2026, 3, 12, 9)),
          reading('b', 9000, DateTime(2026, 3, 12, 21)),
        ],
      ).stepsHistory;
      expect(steps.single.value, 9000);
    });

    test('separate days stay separate, oldest first', () {
      final steps = state(
        steps: [
          reading('b', 5000, DateTime(2026, 3, 12, 9)),
          reading('a', 4000, DateTime(2026, 3, 11, 9)),
        ],
      ).stepsHistory;
      expect([for (final s in steps) s.value], [4000, 5000]);
    });

    test('deleted readings and other authors are left out', () {
      final steps = state(
        steps: [
          reading(
            'gone',
            4000,
            DateTime(2026, 3, 12, 9),
            deletedAt: DateTime(2026, 3, 13),
          ),
          reading('theirs', 6000, DateTime(2026, 3, 12, 9), author: 'friend'),
        ],
      ).stepsHistory;
      expect(steps, isEmpty);
    });

    test("today's steps count; tomorrow's and older than 90 days do not", () {
      final steps = state(
        steps: [
          reading('today', 3000, DateTime(2026, 3, 14, 17)),
          reading('tomorrow', 3000, DateTime(2026, 3, 15, 1)),
          reading('old', 3000, DateTime(2025, 12, 14, 9)),
          reading('edge', 3000, DateTime(2025, 12, 15, 9)),
        ],
      ).stepsHistory;
      expect([for (final s in steps) s.date.day], [15, 14]);
    });
  });

  group('goal progress', () {
    test('no goal leaves the screen empty', () {
      final figures = state(
        measurements: [weighIn('w', DateTime(2026, 3, 10), kg: 80)],
      );
      expect(figures.goalEntries, isEmpty);
      expect(figures.goalTrendKg, isNull);
    });

    test('weigh-ins from before the goal are left out', () {
      final entries = state(
        goal: goal,
        measurements: [
          weighIn('before', DateTime(2026, 3), kg: 83),
          weighIn('after', DateTime(2026, 3, 10), kg: 80),
          weighIn('waist', DateTime(2026, 3, 11), waist: 80),
          weighIn(
            'gone',
            DateTime(2026, 3, 12),
            kg: 70,
            deletedAt: DateTime(2026, 3, 13),
          ),
        ],
      ).goalEntries;
      expect([for (final e in entries) e.id], ['after']);
      expect(entries.single.weightKg, 80);
    });

    test('progress is measured from the trend and runs oldest first', () {
      final figures = state(
        goal: goal,
        measurements: [
          weighIn('b', DateTime(2026, 3, 12), kg: 78),
          weighIn('a', DateTime(2026, 3, 10), kg: 82),
        ],
      );
      final entries = figures.goalEntries;
      expect([for (final e in entries) e.id], ['a', 'b']);
      // The smoothed trend, not the scale: never the full 4 kg.
      expect(
        entries.first.progressPercent,
        lessThanOrEqualTo(entries.last.progressPercent),
      );
      expect(entries.last.progressPercent, inExclusiveRange(0, 100));
      expect(figures.goalTrendKg, inExclusiveRange(78, 82));
    });
  });

  group('units', () {
    test('lengths and weights follow the profile', () {
      final figures = state(
        user: const UserModel(
          userId: uid,
          submittedLengthUnitPreference: LengthUnitPreference.inches,
          submittedWeightUnitPreference: WeightUnitPreference.pounds,
          submittedGender: Gender.female,
        ),
        measurements: [
          weighIn('w', DateTime(2026, 3, 10), kg: 50, waist: 81.28),
        ],
      );
      expect(figures.lengthSymbol, 'in');
      expect(
        figures.measurementReadings(BodyMeasurementKind.waist).single.value,
        closeTo(32, 1e-9),
      );
      expect(figures.unit, AppWeightUnit.pounds);
      expect(figures.weightReadings.single.value, closeTo(110.231, 1e-3));
      expect(figures.sex, maths.Gender.female);
    });

    test("an exercise's own weight unit, else the profile's", () {
      final figures = ProgressState(
        uid: uid,
        now: now,
        firstWeekday: DateTime.monday,
        weightUnits: const {'bench': ExerciseWeightUnit.pounds},
      );
      expect(figures.unitFor('bench'), AppWeightUnit.pounds);
      expect(figures.unitFor('squat'), AppWeightUnit.kilograms);
      expect(figures.copyWith().unitFor('bench'), AppWeightUnit.pounds);
      expect(
        ProgressState(
          uid: uid,
          now: now,
          firstWeekday: DateTime.monday,
          weightUnits: const {'bench': ExerciseWeightUnit.kilograms},
        ).unitFor('bench'),
        AppWeightUnit.kilograms,
      );
    });

    test('without a profile: centimetres and no sex', () {
      final figures = state();
      expect(figures.lengthSymbol, 'cm');
      expect(figures.sex, isNull);
      expect(figures.ratioReadings(maths.BodyRatioKind.waistToHeight), isEmpty);
    });
  });

  group('nutrition', () {
    test("today's totals only once something is logged today", () {
      expect(state(meals: [meal('2026-03-13')]).todayTotals, isNull);
      final today = state(meals: [meal('2026-03-14')]);
      expect(today.todayTotals!.calories, 500);
      expect(today.todayBreakdown.values, [3]);
    });

    test('food logging counts the days with macros this week', () {
      final figures = state(
        meals: [meal('2026-03-09'), meal('2026-03-14'), meal('2026-03-02')],
      );
      expect(figures.foodLoggedThisWeek, 2);
      expect(figures.foodLoggingGrid.where((day) => day), hasLength(3));
      expect(figures.foodLoggingGrid.last, isTrue);
    });
  });

  group('weekly targets', () {
    test('the week starts on its first weekday', () {
      expect(state().weekDayKeys.first, '2026-03-09');
      expect(state().weekDayKeys.last, '2026-03-15');
    });

    test('each column reads its own day', () {
      final week = state(meals: [meal('2026-03-10', calories: 700)]).loggedWeek;
      expect([for (final d in week) d.calories], [0, 700, 0, 0, 0, 0, 0]);
    });

    test("a plan's days are the targets, by weekday", () {
      final targets = state(dietPlan: plan([1, 2, 3, 4, 5, 6, 7])).targetWeek!;
      expect([for (final d in targets) d.calories], [1, 2, 3, 4, 5, 6, 7]);
    });

    test('no plan, or one of the wrong length, invents no targets', () {
      expect(state().targetWeek, isNull);
      expect(state(dietPlan: plan([1, 2, 3])).targetWeek, isNull);
    });
  });

  group('carousel', () {
    test('energy covers 30 days, intake against the plan', () {
      final days = state(
        meals: [meal('2026-03-14', calories: 1800)],
        dietPlan: plan(List.filled(7, 2200)),
      ).energyDays;
      expect(days, hasLength(energyDayCount));
      expect(days.last.date, DateTime(2026, 3, 14));
      expect(days.last.intake, 1800);
      expect(days.last.target, 2200);
      expect(days.first.intake, 0);
      // No strategy settings yet, so no expenditure.
      expect(days.first.expenditure, 0);
    });

    test('energy reads the engine once the settings arrive', () {
      final days = state(
        strategySettings: const NutritionStrategySettings(authorId: uid),
        user: sampleUser(now: now),
      ).energyDays;
      expect(days.last.expenditure, greaterThan(1000));
      expect(days.last.target, isNull);
    });

    test("this week's tally counts only the user's sessions this week", () {
      final figures = state(
        sessions: [
          fixtureSession(
            'mine',
            day: 10,
            author: uid,
            exercises: [
              fixtureExercise('press', sets: [fixtureSet(), fixtureSet()]),
            ],
          ),
          fixtureSession(
            'last week',
            author: uid,
            exercises: [
              fixtureExercise('press', sets: [fixtureSet()]),
            ],
          ),
          fixtureSession(
            'theirs',
            day: 10,
            exercises: [
              fixtureExercise('press', sets: [fixtureSet()]),
            ],
          ),
        ],
      );
      expect(figures.weekTally(), (muscles: 0, sets: 2, exercises: 1));
    });

    // `ProgressCarouselPresenter.workoutTally` with `.activeProgram`.
    test("the Active Program scope counts only that mesocycle's sessions", () {
      final figures = state(
        sessions: [
          fixtureSession(
            'program',
            day: 10,
            author: uid,
            mesocycleId: 'block',
            exercises: [
              fixtureExercise('press', sets: [fixtureSet(), fixtureSet()]),
            ],
          ),
          fixtureSession(
            'extra',
            day: 10,
            author: uid,
            exercises: [
              fixtureExercise('row', sets: [fixtureSet()]),
            ],
          ),
        ],
      );
      expect(figures.weekTally(mesocycleId: 'block'), (
        muscles: 0,
        sets: 2,
        exercises: 1,
      ));
      expect(figures.weekTally(), (muscles: 0, sets: 3, exercises: 2));
    });

    test('records leave out rest days, unfinished and other users', () {
      final figures = state(
        sessions: [
          fixtureSession(
            'mine',
            day: 10,
            author: uid,
            exercises: [
              fixtureExercise('Bench', sets: [fixtureSet(reps: 8)]),
            ],
          ),
          fixtureSession(
            'rest',
            day: 11,
            author: uid,
            isRestDay: true,
            exercises: [
              fixtureExercise('Rest', sets: [fixtureSet(reps: 20)]),
            ],
          ),
          fixtureSession(
            'live',
            day: 12,
            author: uid,
            finished: false,
            exercises: [
              fixtureExercise('Live', sets: [fixtureSet(reps: 20)]),
            ],
          ),
          fixtureSession(
            'theirs',
            day: 12,
            exercises: [
              fixtureExercise('Theirs', sets: [fixtureSet(reps: 20)]),
            ],
          ),
        ],
      );
      expect(
        [for (final r in figures.records(RecordKind.reps)) r.name],
        ['Bench'],
      );
    });
  });
}
