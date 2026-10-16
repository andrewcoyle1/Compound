import 'package:compound/today/logic/today_checklist.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// Mirrors the pure parts of the Swift `TodayChecklistTests` and
/// `TodayPresenterTests`, and the session filter of `WeeklyStreakTests`.
void main() {
  BodyMeasurementEntry weighIn(
    DateTime date,
    double? kg, {
    DateTime? deletedAt,
  }) => BodyMeasurementEntry(
    id: 'w-${date.toIso8601String()}',
    authorId: 'me',
    weightKg: kg,
    date: date,
    source: WeightSource.manual,
    dateCreated: date,
    deletedAt: deletedAt,
  );

  TodayChecklist build({
    WorkoutSessionModel? finished,
    WorkoutTemplateModel? planned,
    double calories = 0,
    double protein = 0,
    double? calorieTarget = 2000,
    double? proteinTarget = 150,
    int meals = 0,
    WeighInItem weighIn = const WeighInItem(isToday: false),
    StepsItem? steps,
  }) => TodayChecklist.build(
    finishedToday: finished,
    planned: planned,
    nutrition: NutritionItem(
      calories: calories,
      proteinGrams: protein,
      mealsLogged: meals,
      calorieTarget: calorieTarget,
      proteinTarget: proteinTarget,
    ),
    weighIn: weighIn,
    steps: steps,
  );

  T? item<T extends ChecklistItem>(TodayChecklist checklist) =>
      checklist.items.whereType<T>().firstOrNull;

  group('TodayChecklist', () {
    test('training is done by a workout and absent without one', () {
      expect(
        item<TrainingItem>(build(finished: fixtureSession('a'))),
        isNotNull,
      );
      expect(
        item<TrainingItem>(build(finished: fixtureSession('a')))!.isDone,
        isTrue,
      );
      expect(item<TrainingItem>(build()), isNull);
      expect(
        TrainingItem(session: fixtureSession('a')),
        TrainingItem(session: fixtureSession('a')),
      );
    });

    // Swift `testTrainingStates`.
    test('training is done, a rest day, planned or left out', () {
      final push = fixtureTemplate(
        'push',
        name: 'Push Day',
        exercises: [fixtureSlot(fixtureLibraryExercise('bench'))],
      );
      final rest = fixtureTemplate('rest', name: 'Rest');
      final done = item<TrainingItem>(
        build(finished: fixtureSession('a'), planned: push),
      )!;
      expect(done.isDone, isTrue);
      expect(done.session?.id, 'a');
      final restDay = item<TrainingItem>(build(planned: rest))!;
      expect(restDay.isRestDay, isTrue);
      expect(restDay.isDone, isTrue);
      final planned = item<TrainingItem>(build(planned: push))!;
      expect(planned.isRestDay, isFalse);
      expect(planned.isDone, isFalse);
      expect(item<TrainingItem>(build()), isNull);
    });

    test('nutrition needs calories in the band and protein reached', () {
      bool done(double calories, double protein) =>
          item<NutritionItem>(build(calories: calories, protein: protein))!
              .isDone;
      expect(done(1950, 150), isTrue);
      expect(done(1700, 160), isFalse);
      expect(done(2300, 160), isFalse);
      expect(done(2000, 120), isFalse);
      // No protein target: calories alone.
      expect(
        item<NutritionItem>(build(calories: 2000, proteinTarget: 0))!.isDone,
        isTrue,
      );
    });

    test('without a plan logging a meal completes nutrition', () {
      expect(item<NutritionItem>(build(calorieTarget: null))!.isDone, isFalse);
      expect(
        item<NutritionItem>(
          build(calories: 600, calorieTarget: null, meals: 1),
        )!.isDone,
        isTrue,
      );
    });

    test('the weigh-in is done once weighed today', () {
      expect(item<WeighInItem>(build())!.isDone, isFalse);
      expect(
        item<WeighInItem>(
          build(weighIn: const WeighInItem(isToday: true, latestKg: 80)),
        )!.isDone,
        isTrue,
      );
    });

    test('steps appear only with step data and complete at the goal', () {
      expect(item<StepsItem>(build()), isNull);
      expect(
        item<StepsItem>(build(steps: const StepsItem(today: 6000, goal: 8000)))!
            .isDone,
        isFalse,
      );
      expect(
        item<StepsItem>(build(steps: const StepsItem(today: 8000, goal: 8000)))!
            .isDone,
        isTrue,
      );
    });

    // Swift `testDayComplete`.
    test('a rest day counts toward a complete day', () {
      final rest = fixtureTemplate('rest');
      final partial = build(planned: rest, calories: 2000, protein: 150);
      expect(partial.doneCount, 2);
      expect(partial.isComplete, isFalse);
      expect(
        build(
          planned: rest,
          calories: 2000,
          protein: 150,
          weighIn: const WeighInItem(isToday: true, latestKg: 80),
        ).isComplete,
        isTrue,
      );
    });

    test('the day is complete when every item is done', () {
      final partial = build(
        finished: fixtureSession('a'),
        calories: 2000,
        protein: 150,
      );
      expect(partial.doneCount, 2);
      expect(partial.isComplete, isFalse);

      final complete = build(
        finished: fixtureSession('a'),
        calories: 2000,
        protein: 150,
        weighIn: const WeighInItem(isToday: true, latestKg: 80),
      );
      expect(complete.isComplete, isTrue);
      expect(
        complete,
        build(
          finished: fixtureSession('a'),
          calories: 2000,
          protein: 150,
          weighIn: const WeighInItem(isToday: true, latestKg: 80),
        ),
      );
      expect(const TodayChecklist([]).isComplete, isFalse);
    });
  });

  group('weighInChange', () {
    test('is from the last weigh-in a week before the latest', () {
      DateTime day(int offset) =>
          DateTime(2026, 6, 1, 8).add(Duration(days: offset));
      final entries = [
        weighIn(day(0), 81),
        weighIn(day(2), 80.8),
        weighIn(day(9), 80.5),
        weighIn(day(10), 99, deletedAt: day(10)),
        weighIn(day(10), null),
      ];

      final trend = weighInChange(entries);
      expect(trend.latest?.weightKg, 80.5);
      expect(trend.weekChangeKg, closeTo(-0.3, 0.001));
      expect(weighInChange(entries.take(2)).weekChangeKg, isNull);
      expect(weighInChange(const []).latest, isNull);
    });
  });

  group('training', () {
    final now = marchDay(14);

    test('rest days, unfinished, deleted and others never count', () {
      final sessions = [
        fixtureSession('a', day: 9, author: 'me'),
        fixtureSession('rest', day: 10, author: 'me', isRestDay: true),
        fixtureSession('open', day: 11, author: 'me', finished: false),
        WorkoutSessionModel(
          id: 'deleted',
          authorId: 'me',
          name: 'Deleted',
          dateCreated: marchDay(12),
          dateModified: marchDay(12),
          endedAt: marchDay(12),
          deletedAt: marchDay(12),
          exercises: const [],
        ),
        fixtureSession('friend', day: 12),
        fixtureSession('future', day: 15, author: 'me'),
      ];
      expect(countedSessions(sessions, uid: 'me', now: now).map((s) => s.id), [
        'a',
      ]);
    });

    test("today's own workout is the newest finished today", () {
      final sessions = [
        fixtureSession('early', day: 14, author: 'me', minutes: 10),
        fixtureSession('late', day: 14, author: 'me', minutes: 90),
        fixtureSession('mid', day: 14, author: 'me', minutes: 30),
        fixtureSession('rest', day: 14, author: 'me', isRestDay: true),
        fixtureSession('yesterday', day: 13, author: 'me'),
        fixtureSession('friend', day: 14),
        fixtureSession('open', day: 14, author: 'me', finished: false),
      ];
      expect(sessionFinishedToday(sessions, uid: 'me', now: now)?.id, 'late');
      expect(sessionFinishedToday(const [], uid: 'me', now: now), isNull);
    });
  });

  group('goalWeeklyChangeKg', () {
    WeightGoal goal(OverarchingObjective objective, GoalStatus status) =>
        WeightGoal(
          goalId: 'g',
          userId: 'me',
          objective: objective,
          startingWeightKg: 80,
          targetWeightKg: 75,
          weeklyChangeKg: 0.5,
          createdAt: marchDay(1),
          status: status,
        );

    test('is signed by objective, and only for an active goal', () {
      expect(
        goalWeeklyChangeKg(
          goal(OverarchingObjective.loseWeight, GoalStatus.active),
        ),
        -0.5,
      );
      expect(
        goalWeeklyChangeKg(
          goal(OverarchingObjective.gainWeight, GoalStatus.active),
        ),
        0.5,
      );
      expect(
        goalWeeklyChangeKg(
          goal(OverarchingObjective.maintain, GoalStatus.active),
        ),
        isNull,
      );
      expect(
        goalWeeklyChangeKg(
          goal(OverarchingObjective.loseWeight, GoalStatus.paused),
        ),
        isNull,
      );
      expect(goalWeeklyChangeKg(null), isNull);
    });
  });

  group('steps', () {
    test('the default step goal follows age', () {
      final now = DateTime(2026, 10, 9, 12);
      expect(ageAdjustedStepGoal(null, now: now), 8000);
      expect(ageAdjustedStepGoal(DateTime(1990), now: now), 8000);
      expect(ageAdjustedStepGoal(DateTime(1966, 10, 10), now: now), 8000);
      expect(ageAdjustedStepGoal(DateTime(1966, 10, 9), now: now), 7000);
      expect(ageAdjustedStepGoal(DateTime(1966, 9, 30), now: now), 7000);
    });

    test("today's steps add up today's live counts", () {
      StepsModel steps(DateTime date, int number, {bool deleted = false}) =>
          StepsModel(
            id: 's-$number',
            authorId: 'me',
            number: number,
            date: date,
            source: StepsSource.healthkit,
            dateCreated: date,
            dateModified: date,
            deletedAt: deleted ? date : null,
          );
      final now = marchDay(14);
      expect(
        stepsOn([
          steps(marchDay(14), 3000),
          steps(marchDay(14), 1000),
          steps(marchDay(14), 500, deleted: true),
          steps(marchDay(13), 9000),
        ], now),
        4000,
      );
    });
  });

  test('getting started lists what is left', () {
    expect(
      remainingStarterSteps(
        hasWorkout: false,
        hasMeal: false,
        hasWeighIn: false,
        hasStepData: false,
        stravaConnected: false,
      ),
      StarterStep.values,
    );
    expect(
      remainingStarterSteps(
        hasWorkout: true,
        hasMeal: false,
        hasWeighIn: true,
        hasStepData: true,
        stravaConnected: true,
      ),
      [StarterStep.firstMeal],
    );
    expect(
      remainingStarterSteps(
        hasWorkout: true,
        hasMeal: true,
        hasWeighIn: true,
        hasStepData: false,
        stravaConnected: false,
      ),
      [StarterStep.appleHealth, StarterStep.strava],
    );
    expect(
      remainingStarterSteps(
        hasWorkout: true,
        hasMeal: true,
        hasWeighIn: true,
        hasStepData: true,
        stravaConnected: true,
      ),
      isEmpty,
    );
  });

  group('proteinGap', () {
    test('shows from 5pm when at least 20 g short of a target', () {
      final evening = DateTime(2026, 3, 14, 17);
      expect(proteinGap(now: evening, targetGrams: 150, eatenGrams: 100), 50);
      expect(
        proteinGap(now: evening, targetGrams: 150, eatenGrams: 131),
        isNull,
      );
      expect(
        proteinGap(
          now: DateTime(2026, 3, 14, 16, 59),
          targetGrams: 150,
          eatenGrams: 0,
        ),
        isNull,
      );
      expect(
        proteinGap(now: evening, targetGrams: null, eatenGrams: 0),
        isNull,
      );
      expect(proteinGap(now: evening, targetGrams: 0, eatenGrams: 0), isNull);
    });
  });

  // Swift `testSocialPulse`.
  group('namesTrainedToday', () {
    final now = DateTime(2026, 3, 14, 18);
    UserModel user(String id, {String? first, String? display}) =>
        UserModel(userId: id, submittedFirstName: first, displayName: display);
    WorkoutSessionModel session(
      String id,
      String author, {
      int day = 14,
      int hour = 9,
      bool isRestDay = false,
    }) => WorkoutSessionModel(
      id: id,
      authorId: author,
      name: id,
      dateCreated: DateTime(2026, 3, day, hour),
      dateModified: DateTime(2026, 3, day, hour),
      endedAt: DateTime(2026, 3, day, hour + 1),
      isRestDay: isRestDay,
      exercises: const [],
    );

    test('are the people followed who finished a workout today, once', () {
      expect(
        namesTrainedToday(
          sessions: [
            session('s1', 'sam', hour: 7),
            session('s2', 'sam'),
            session('r', 'alex', isRestDay: true),
            session('x', 'stranger'),
            session('old', 'alex', day: 12),
          ],
          following: [
            user('sam', first: 'Sam'),
            user('alex', first: 'Alex'),
          ],
          now: now,
        ),
        ['Sam'],
      );
    });

    test('in the order they finished, by first name or display name', () {
      expect(
        namesTrainedToday(
          sessions: [
            session('a', 'alex', hour: 10),
            session('b', 'blake', hour: 8),
            session('c', 'casey'),
            session('d', 'nameless', hour: 11),
          ],
          following: [
            user('alex', first: 'Alex'),
            user('alex', first: 'Second Alex'),
            user('blake', first: '', display: 'Blake B'),
            user('casey', first: 'Casey'),
            user('nameless'),
          ],
          now: now,
        ),
        ['Blake B', 'Casey', 'Alex'],
      );
    });
  });

  test('the step goals offered', () {
    expect(stepGoalChoices, [5000, 6000, 8000, 10000, 12000, 15000]);
  });
}
