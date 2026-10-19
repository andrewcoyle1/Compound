// The Weekly Review's numbers, ported case for case from the Swift
// WeeklyReviewTests: the week under review is Monday 9 to Sunday 15 March
// 2026, starting on Monday.
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:compound/weekly_review/logic/weekly_review.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  const me = 'me';
  final weekStart = DateTime(2026, 3, 9);
  final l10n = lookupAppLocalizations(const Locale('en'));

  WorkoutSetModel set({
    int reps = 5,
    double weightKg = 100,
    double? rpe,
    bool isWarmup = false,
  }) =>
      fixtureSet(reps: reps, weightKg: weightKg, rpe: rpe, isWarmup: isWarmup);

  WorkoutExerciseModel exercise(String name, List<WorkoutSetModel> sets) =>
      fixtureExercise(name, sets: sets);

  WorkoutSessionModel session(
    String id,
    int day, {
    String author = me,
    List<WorkoutExerciseModel> exercises = const [],
  }) => fixtureSession(id, day: day, author: author, exercises: exercises);

  BodyMeasurementEntry weighIn(double kg, int day, {bool deleted = false}) =>
      BodyMeasurementEntry(
        id: 'w-$kg-$day',
        authorId: me,
        weightKg: kg,
        date: DateTime(2026, 3, day, 9),
        source: WeightSource.manual,
        dateCreated: DateTime(2026, 3, day, 9),
        deletedAt: deleted ? DateTime(2026, 3, day, 9) : null,
      );

  MealLogModel meal(double calories, int day) => MealLogModel(
    mealId: 'meal-$calories-$day',
    authorId: me,
    dayKey: '2026-03-${day.toString().padLeft(2, '0')}',
    date: DateTime(2026, 3, day, 12),
    items: [
      MealItemModel(
        itemId: 'item-$calories-$day',
        sourceType: MealItemSourceType.ingredient,
        sourceId: 'x',
        displayName: 'Food',
        amount: 1,
        unit: 'serving',
        nutrients: NutrientMap({NutrientKey.calories: calories}),
      ),
    ],
  );

  DietPlan plan(List<double> calories) => DietPlan(
    planId: 'plan',
    createdAt: DateTime(2026),
    tdeeEstimate: 2500,
    preferredDiet: 'balanced',
    calorieFloor: 'standard',
    trainingType: 'strength',
    calorieDistribution: 'even',
    proteinIntake: 'high',
    days: [
      for (final c in calories)
        DailyMacroTarget(
          calories: c,
          proteinGrams: 0,
          carbGrams: 0,
          fatGrams: 0,
        ),
    ],
  );

  WeeklyReview build({
    List<WorkoutSessionModel> sessions = const [],
    List<BodyMeasurementEntry> measurements = const [],
    List<MealLogModel> meals = const [],
    int goal = 3,
    List<ExerciseModel> library = const [],
    DietPlan? dietPlan,
    DateTime? start,
  }) => WeeklyReview.build(
    sessions: sessions,
    measurements: measurements,
    meals: meals,
    weekStart: start ?? weekStart,
    uid: me,
    goal: goal,
    library: library,
    muscleName: l10n.muscleName,
    dietPlan: dietPlan,
  );

  group('sessions and volume', () {
    test("only the user's sessions in the week count", () {
      final review = build(
        sessions: [
          session('a', 9),
          session('b', 15),
          session('last-week', 8),
          session('next-week', 16),
          session('friend', 10, author: 'friend'),
        ],
      );
      expect(review.sessionCount, 2);
      expect(review.goal, 3);
      expect(review.weekEnd, DateTime(2026, 3, 16));
    });

    test('volume compares with last week and skips warm-ups', () {
      final review = build(
        sessions: [
          session(
            'last',
            3,
            exercises: [
              exercise('Bench', [set(reps: 10)]),
            ],
          ),
          session(
            'this',
            10,
            exercises: [
              exercise('Bench', [
                set(reps: 11),
                set(reps: 10, weightKg: 50, isWarmup: true),
              ]),
            ],
          ),
        ],
      );
      expect(review.volumeKg, 1100);
      expect(review.previousVolumeKg, 1000);
      expect(review.volumeChange, closeTo(0.1, 1e-9));
      expect(review.volumeUnit, ExerciseWeightUnit.kilograms);
    });

    test('no volume last week has no comparison', () {
      final review = build(
        sessions: [
          session(
            'this',
            10,
            exercises: [
              exercise('Bench', [set()]),
            ],
          ),
        ],
      );
      expect(review.volumeChange, isNull);
    });

    test('a week lifted mostly in pounds reads in pounds', () {
      final review = build(
        sessions: [
          session(
            'this',
            10,
            exercises: [
              exercise('Curl', [
                fixtureSet(weightUnit: 'pounds'),
                fixtureSet(weightUnit: 'pounds'),
                fixtureSet(weightUnit: 'kilograms'),
              ]),
            ],
          ),
        ],
      );
      expect(review.volumeUnit, ExerciseWeightUnit.pounds);
    });
  });

  group('muscles, records and RPE', () {
    test('secondary muscles count half and the most come first', () {
      final review = build(
        sessions: [
          session(
            'a',
            10,
            exercises: [
              exercise('Bench', [set(), set(), set(isWarmup: true)]),
            ],
          ),
        ],
        library: [
          fixtureLibraryExercise(
            'Bench',
            muscles: const {
              Muscles.chest: MuscleTargetType.primary,
              Muscles.triceps: MuscleTargetType.secondary,
            },
          ),
        ],
      );
      expect(review.setsPerMuscle, [
        (muscle: Muscles.chest, sets: 2.0),
        (muscle: Muscles.triceps, sets: 1.0),
      ]);
    });

    test('only hard sets count, and equal muscles go by name', () {
      final review = build(
        sessions: [
          session(
            'a',
            10,
            exercises: [
              exercise('Bench', [set(rpe: 8), set(rpe: 5), set()]),
            ],
          ),
        ],
        library: [
          fixtureLibraryExercise(
            'Bench',
            muscles: const {
              Muscles.triceps: MuscleTargetType.primary,
              Muscles.chest: MuscleTargetType.primary,
            },
          ),
        ],
      );
      expect(review.setsPerMuscle, [
        (muscle: Muscles.chest, sets: 2.0),
        (muscle: Muscles.triceps, sets: 2.0),
      ]);
    });

    test('a lift beaten twice in the week lists its latest record once', () {
      final review = build(
        sessions: [
          session(
            'old',
            2,
            exercises: [
              exercise('Bench', [set(weightKg: 90)]),
              exercise('Squat', [set(weightKg: 140)]),
            ],
          ),
          session(
            'mon',
            9,
            exercises: [
              exercise('Bench', [set(weightKg: 95)]),
            ],
          ),
          session(
            'thu',
            12,
            exercises: [
              exercise('Bench', [set()]),
              exercise('Squat', [set(weightKg: 150)]),
            ],
          ),
        ],
      );
      expect(
        [
          for (final r in review.personalRecords)
            [
              r.exerciseName,
              WorkoutText.recordDetail(l10n, r, locale: 'en'),
            ].join(' '),
        ],
        ['Bench 100\u00a0kg × 5', 'Squat 150\u00a0kg × 5'],
      );
    });

    test('average RPE uses only sets that recorded one', () {
      final tracked = build(
        sessions: [
          session(
            'a',
            10,
            exercises: [
              exercise('Bench', [set(rpe: 7), set(rpe: 8), set()]),
            ],
          ),
        ],
      );
      expect(tracked.averageRpe, 7.5);
      final untracked = build(
        sessions: [
          session(
            'a',
            10,
            exercises: [
              exercise('Bench', [set()]),
            ],
          ),
        ],
      );
      expect(untracked.averageRpe, isNull);
    });
  });

  group('weight', () {
    test(
      "the change is the trend's from the last weigh-in before the week",
      () {
        final review = build(
          measurements: [
            weighIn(80, 5),
            weighIn(79.5, 7),
            weighIn(79.2, 10),
            weighIn(79, 14),
            weighIn(70, 13, deleted: true),
          ],
        );
        expect(review.latestWeightKg, closeTo(79.07, 0.05));
        expect(review.weightChangeKg, closeTo(-0.32, 0.05));
      },
    );

    test('without earlier weigh-ins the change is within the week', () {
      final one = build(measurements: [weighIn(80, 10)]);
      expect(one.latestWeightKg, 80);
      expect(one.weightChangeKg, isNull);
      final two = build(measurements: [weighIn(80, 10), weighIn(81, 12)]);
      expect(two.weightChangeKg, greaterThan(0));
    });

    test('later weigh-ins do not change a past week', () {
      final measured = [
        weighIn(80, 5),
        weighIn(79.5, 7),
        weighIn(79.2, 10),
        weighIn(79, 14),
      ];
      final later = [...measured, weighIn(76, 20), weighIn(75.5, 21)];
      expect(
        build(measurements: measured).weightChangeKg,
        build(measurements: later).weightChangeKg,
      );
    });

    test('no weigh-in that week shows no weight', () {
      expect(build(measurements: [weighIn(80, 3)]).latestWeightKg, isNull);
    });
  });

  group('nutrition', () {
    test("counts logged days within ten percent of that day's target", () {
      // Monday first: day 9 is a Monday (2000), day 10 a Tuesday (2500),
      // day 11 a Wednesday with no target.
      final review = build(
        meals: [
          meal(1000, 9),
          meal(1100, 9),
          meal(2000, 10),
          meal(2000, 11),
          meal(5000, 2),
        ],
        dietPlan: plan([2000, 2500, 0, 2000, 2000, 2000, 2000]),
      );
      expect(review.nutrition, (daysOnTarget: 1, daysLogged: 3));
    });

    test('a day near its target counts', () {
      final review = build(
        meals: [meal(1000, 9), meal(1100, 9), meal(2400, 10)],
        dietPlan: plan([2000, 2500, 2000, 2000, 2000, 2000, 2000]),
      );
      expect(review.nutrition, (daysOnTarget: 2, daysLogged: 2));
    });

    test('without targets there is no adherence', () {
      expect(build(meals: [meal(2000, 10)]).nutrition, isNull);
      expect(
        build(meals: [meal(2000, 10)], dietPlan: plan([])).nutrition,
        isNull,
      );
    });
  });

  group('takeaway', () {
    test('picks the first that applies', () {
      expect(build().takeaway, const NoSessionsTakeaway());

      final prWeek = build(
        sessions: [
          session(
            'old',
            2,
            exercises: [
              exercise('Bench', [set(weightKg: 90)]),
            ],
          ),
          session('a', 9),
          session('b', 10),
          session(
            'c',
            11,
            exercises: [
              exercise('Bench', [set()]),
            ],
          ),
        ],
      );
      expect(prWeek.takeaway, const GoalAndRecordsTakeaway(1));

      expect(
        build(sessions: [session('a', 9)], goal: 1).takeaway,
        const GoalHitTakeaway(1, 1),
      );

      final volumeUp = build(
        sessions: [
          session(
            'last',
            3,
            exercises: [
              exercise('Bench', [set(reps: 10, weightKg: 50)]),
            ],
          ),
          session(
            'this',
            10,
            exercises: [
              exercise('Bench', [set(reps: 10, weightKg: 60)]),
            ],
          ),
        ],
      );
      expect(volumeUp.takeaway, isA<VolumeUpTakeaway>());
      expect(
        (volumeUp.takeaway as VolumeUpTakeaway).change,
        closeTo(0.2, 1e-9),
      );

      expect(
        build(sessions: [session('a', 9)]).takeaway,
        const SessionsToGoTakeaway(2),
      );
    });
  });
}
