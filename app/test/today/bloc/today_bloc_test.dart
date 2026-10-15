import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/today/logic/today_checklist.dart';
import 'package:compound/today/today.dart';
import 'package:compound_maths/compound_maths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository;

class _FakeEvent extends Fake implements LoggableEvent;

void main() {
  const uid = 'me';
  // Saturday 14 March 2026, 6pm: the week (from Monday) is 9–15 March.
  final now = DateTime(2026, 3, 14, 18);

  MealLogModel meal(String id, {double calories = 500, double protein = 40}) =>
      MealLogModel(
        mealId: id,
        authorId: uid,
        dayKey: '2026-03-14',
        date: DateTime(2026, 3, 14, 12),
        items: [
          MealItemModel(
            itemId: '$id-item',
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

  DietPlan plan() => DietPlan(
    planId: 'plan',
    createdAt: DateTime(2026, 3),
    tdeeEstimate: 2500,
    preferredDiet: 'balanced',
    calorieFloor: 'standard',
    trainingType: 'strength',
    calorieDistribution: 'even',
    proteinIntake: 'high',
    days: [
      for (var i = 0; i < 7; i++)
        const DailyMacroTarget(
          calories: 2000,
          proteinGrams: 150,
          carbGrams: 200,
          fatGrams: 60,
        ),
    ],
  );

  BodyMeasurementEntry weighIn(DateTime date, double kg) =>
      BodyMeasurementEntry(
        id: 'w-$kg',
        authorId: uid,
        weightKg: kg,
        date: date,
        source: WeightSource.manual,
        dateCreated: date,
      );

  WeightGoal goal(String id) => WeightGoal(
    goalId: id,
    userId: uid,
    objective: OverarchingObjective.loseWeight,
    startingWeightKg: 80,
    targetWeightKg: 75,
    weeklyChangeKg: 0.5,
    createdAt: DateTime(2026, 3),
    status: GoalStatus.active,
  );

  final sessions = [
    for (final day in [9, 10, 12])
      fixtureSession('s$day', day: day, author: uid),
    fixtureSession('rest', day: 11, author: uid, isRestDay: true),
    // Last week met too.
    for (final day in [2, 4, 6]) fixtureSession('p$day', day: day, author: uid),
  ];

  late WorkoutSessionRepository workoutSessionRepository;
  late NutritionRepository nutritionRepository;
  late BodyRepository bodyRepository;
  late UserRepository userRepository;
  late AnalyticsRepository analyticsRepository;

  setUpAll(() => registerFallbackValue(_FakeEvent()));

  setUp(() {
    workoutSessionRepository = MockWorkoutSessionRepository();
    nutritionRepository = MockNutritionRepository();
    bodyRepository = MockBodyRepository();
    userRepository = MockUserRepository();
    analyticsRepository = _MockAnalyticsRepository();
    when(() => workoutSessionRepository.watchSessions(uid))
        .thenAnswer((_) => Stream.value(sessions));
    when(() => nutritionRepository.watchMeals(uid))
        .thenAnswer((_) => Stream.value([meal('a'), meal('b')]));
    when(() => nutritionRepository.watchDietPlan(uid))
        .thenAnswer((_) => Stream.value(plan()));
    when(() => bodyRepository.watchMeasurements(uid)).thenAnswer(
      (_) => Stream.value([
        weighIn(DateTime(2026, 3, 6, 7), 81),
        weighIn(DateTime(2026, 3, 14, 7), 80.4),
      ]),
    );
    when(() => bodyRepository.watchSteps(uid)).thenAnswer(
      (_) => Stream.value([
        StepsModel(
          id: 'steps',
          authorId: uid,
          number: 9000,
          date: DateTime(2026, 3, 14),
          source: StepsSource.healthkit,
          dateCreated: now,
          dateModified: now,
        ),
      ]),
    );
    when(
      () => bodyRepository.watchAnalyticsSettings(uid),
    ).thenAnswer((_) => Stream.value(const AnalyticsSettings(authorId: uid)));
    when(() => userRepository.watchUser(uid)).thenAnswer(
      (_) => Stream.value(
        const UserModel(
          userId: uid,
          submittedWeightUnitPreference: WeightUnitPreference.pounds,
          weeklySessionGoal: 3,
        ),
      ),
    );
    when(
      () => bodyRepository.watchCurrentGoal(
        uid,
        currentGoalId: any(named: 'currentGoalId'),
      ),
    ).thenAnswer((_) => Stream.value(goal(uid)));
  });

  TodayBloc build() => TodayBloc(
    workoutSessionRepository: workoutSessionRepository,
    nutritionRepository: nutritionRepository,
    bodyRepository: bodyRepository,
    userRepository: userRepository,
    analyticsRepository: analyticsRepository,
    uid: uid,
    firstWeekday: DateTime.monday,
    now: () => now,
  );

  group(TodayBloc, () {
    test('opens loading', () {
      final state = build().state;
      expect(state.status, TodayStatus.loading);
      expect(state.now, now);
      expect(state.uid, uid);
    });

    blocTest<TodayBloc, TodayState>(
      'builds the day from every repository',
      build: build,
      act: (bloc) => bloc.add(const TodaySubscriptionRequested()),
      verify: (bloc) {
        final state = bloc.state;
        verify(
          () => analyticsRepository.trackScreenView(
            any(
              that: isA<LoggableEvent>().having(
                (e) => e.eventName,
                'eventName',
                'TodayView_Appear',
              ),
            ),
          ),
        ).called(1);
        expect(state.status, TodayStatus.loaded);
        expect(state.usesPounds, isTrue);
        expect(state.goal?.goalId, uid);

        final items = state.checklist.items;
        expect(items, hasLength(3));
        final nutrition = items.whereType<NutritionItem>().single;
        expect(nutrition.calories, 1000);
        expect(nutrition.calorieTarget, 2000);
        expect(nutrition.mealsLogged, 2);
        final weighIn = items.whereType<WeighInItem>().single;
        expect(weighIn.isDone, isTrue);
        expect(weighIn.weekChangeKg, closeTo(-0.6, 1e-9));
        expect(weighIn.goalWeeklyChangeKg, -0.5);
        expect(items.whereType<StepsItem>().single.goal, 8000);

        final streak = state.streak;
        expect(streak.weeks, 2);
        expect(streak.state, StreakState.met);
        expect(state.totalWorkouts, 6);
        expect(state.workoutDaysThisWeek, {
          '2026-03-09',
          '2026-03-10',
          '2026-03-12',
        });
        expect(state.weekDays.first, DateTime(2026, 3, 9));
        expect(state.weekDays.last, DateTime(2026, 3, 15));
        expect(state.starterSteps, isEmpty);
        // 150 g target, 80 g eaten, after 5pm.
        expect(state.proteinGapGrams, 70);
      },
    );

    blocTest<TodayBloc, TodayState>(
      'fails when the sessions, meals or weigh-ins cannot be read',
      setUp: () =>
          when(() => nutritionRepository.watchMeals(uid))
              .thenAnswer((_) => Stream.error(Exception('offline'))),
      build: build,
      act: (bloc) => bloc.add(const TodaySubscriptionRequested()),
      verify: (bloc) => expect(bloc.state.status, TodayStatus.failure),
    );

    blocTest<TodayBloc, TodayState>(
      'falls back when the niceties cannot be read',
      setUp: () {
        when(() => nutritionRepository.watchDietPlan(uid))
            .thenAnswer((_) => Stream.error(Exception('plan')));
        when(() => bodyRepository.watchSteps(uid))
            .thenAnswer((_) => Stream.error(Exception('steps')));
        when(() => bodyRepository.watchAnalyticsSettings(uid))
            .thenAnswer((_) => Stream.error(Exception('settings')));
        when(() => userRepository.watchUser(uid))
            .thenAnswer((_) => Stream.error(Exception('user')));
        when(
          () => bodyRepository.watchCurrentGoal(
            uid,
            currentGoalId: any(named: 'currentGoalId'),
          ),
        ).thenAnswer((_) => Stream.error(Exception('goal')));
      },
      build: build,
      act: (bloc) => bloc.add(const TodaySubscriptionRequested()),
      verify: (bloc) {
        final state = bloc.state;
        expect(state.status, TodayStatus.loaded);
        expect(state.dietPlan, isNull);
        expect(state.goal, isNull);
        expect(state.usesPounds, isFalse);
        expect(state.stepGoal, 8000);
        expect(state.checklist.items.whereType<StepsItem>(), isEmpty);
        expect(state.proteinGapGrams, isNull);
      },
    );

    group('the goal', () {
      late StreamController<UserModel?> users;

      setUp(() {
        users = StreamController<UserModel?>();
        when(() => userRepository.watchUser(uid))
            .thenAnswer((_) => users.stream);
        when(() => bodyRepository.watchCurrentGoal(uid, currentGoalId: 'next'))
            .thenAnswer((_) => Stream.value(goal('next')));
      });

      tearDown(() => users.close());

      blocTest<TodayBloc, TodayState>(
        "follows the user's current goal id",
        build: build,
        act: (bloc) async {
          bloc.add(const TodaySubscriptionRequested());
          await Future<void>.delayed(Duration.zero);
          users
            ..add(const UserModel(userId: uid))
            ..add(const UserModel(userId: uid));
          await Future<void>.delayed(Duration.zero);
          users.add(
            const UserModel(userId: uid, submittedCurrentGoalId: 'next'),
          );
          await Future<void>.delayed(Duration.zero);
        },
        verify: (bloc) {
          expect(bloc.state.goal?.goalId, 'next');
          verify(() => bodyRepository.watchCurrentGoal(uid)).called(1);
          verify(
            () => bodyRepository.watchCurrentGoal(uid, currentGoalId: 'next'),
          ).called(1);
        },
      );
    });
  });

  test('a user without a step goal of their own gets the age default', () {
    final state = TodayState(
      uid: uid,
      now: now,
      firstWeekday: DateTime.monday,
      user: UserModel(userId: uid, submittedDateOfBirth: DateTime(1950)),
      analyticsSettings: const AnalyticsSettings(authorId: uid),
    );
    expect(state.stepGoal, 7000);
    expect(state.copyWith().stepGoal, 7000);
    expect(
      TodayState(
        uid: uid,
        now: now,
        firstWeekday: DateTime.monday,
        analyticsSettings: const AnalyticsSettings(
          authorId: uid,
          dailyStepGoal: 12000,
        ),
      ).stepGoal,
      12000,
    );
  });

  test('a new account has every starter step left', () {
    final state = TodayState(
      uid: uid,
      now: now,
      firstWeekday: DateTime.monday,
      sessions: const [],
      meals: const [],
      measurements: const [],
    );
    expect(state.starterSteps, StarterStep.values);
    expect(state.streak.state, StreakState.none);
  });
}
