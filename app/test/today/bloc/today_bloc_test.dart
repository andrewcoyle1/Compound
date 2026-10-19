import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/today/logic/today_checklist.dart';
import 'package:compound/today/today.dart';
import 'package:compound_maths/compound_maths.dart';
import 'package:device_store/device_store.dart';
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
  late DeviceStore store;

  setUpAll(() => registerFallbackValue(_FakeEvent()));

  setUp(() {
    store = InMemoryDeviceStore();
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
    checkInRepository: InMemoryCheckInRepository(),
    uid: uid,
    firstWeekday: DateTime.monday,
    store: store,
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

  group('Swift TodayPresenterTests', () {
    List<LoggableEvent> tracked() =>
        verify(() => analyticsRepository.trackEvent(captureAny())).captured
            .cast<LoggableEvent>();

    setUp(() {
      when(() => bodyRepository.saveStepGoal(any(), any()))
          .thenAnswer((_) async {});
    });

    setUpAll(
      () => registerFallbackValue(const AnalyticsSettings(authorId: uid)),
    );

    // `testStepGoal`.
    blocTest<TodayBloc, TodayState>(
      'choosing a step goal saves it and shows it',
      build: build,
      act: (bloc) async {
        bloc.add(const TodaySubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.stepGoal, 8000);
        bloc.add(const TodayStepGoalSelected(10000));
      },
      verify: (bloc) {
        expect(bloc.state.stepGoal, 10000);
        expect(bloc.state.stepGoalSaves, 1);
        // Only the goal is written (Swift rewrites the whole document).
        verify(() => bodyRepository.saveStepGoal(uid, 10000)).called(1);
        final start = tracked().singleWhere(
          (e) => e.eventName == 'TodayView_StepGoal_Start',
        );
        expect(start.parameters, {'goal': 10000});
      },
    );

    // `testAnOlderUsersChosenStepGoalIsKept`: 8,000 is saved although the
    // age default shows 7,000.
    blocTest<TodayBloc, TodayState>(
      "an older user's chosen goal is kept",
      setUp: () => when(() => userRepository.watchUser(uid)).thenAnswer(
        (_) => Stream.value(
          UserModel(userId: uid, submittedDateOfBirth: DateTime(1956)),
        ),
      ),
      build: build,
      act: (bloc) async {
        bloc.add(const TodaySubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.stepGoal, 7000);
        bloc.add(const TodayStepGoalSelected(8000));
      },
      verify: (bloc) {
        expect(bloc.state.stepGoal, 8000);
        verify(() => bodyRepository.saveStepGoal(uid, 8000)).called(1);
      },
    );

    blocTest<TodayBloc, TodayState>(
      'choosing the goal already stored saves nothing',
      setUp: () => when(() => bodyRepository.watchAnalyticsSettings(uid))
          .thenAnswer(
            (_) => Stream.value(
              const AnalyticsSettings(authorId: uid, dailyStepGoal: 6000),
            ),
          ),
      build: build,
      act: (bloc) async {
        bloc.add(const TodaySubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TodayStepGoalSelected(6000));
      },
      verify: (_) =>
          verifyNever(() => bodyRepository.saveStepGoal(any(), any())),
    );

    blocTest<TodayBloc, TodayState>(
      'a goal that fails to save goes back and says so',
      setUp: () =>
          when(() => bodyRepository.saveStepGoal(any(), any()))
              .thenThrow(Exception('denied')),
      build: build,
      act: (bloc) async {
        bloc.add(const TodaySubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TodayStepGoalSelected(12000));
      },
      verify: (bloc) {
        expect(bloc.state.stepGoal, 8000);
        expect(bloc.state.stepGoalFailures, 1);
        expect(bloc.state.stepGoalSaves, 0);
        final fail = tracked().singleWhere(
          (e) => e.eventName == 'TodayView_StepGoal_Fail',
        );
        expect(fail.type, LogType.severe);
      },
    );

    // `testDayCompleteOnce`.
    blocTest<TodayBloc, TodayState>(
      'the day is marked complete once',
      build: build,
      act: (bloc) => bloc
        ..add(const TodayDayCompleted(3))
        ..add(const TodayDayCompleted(3)),
      expect: () => [
        isA<TodayState>().having((s) => s.dayCompletions, 'completions', 1),
      ],
      verify: (_) {
        final complete = tracked().where(
          (e) => e.eventName == 'TodayView_DayComplete',
        );
        expect(complete, hasLength(1));
        expect(complete.single.parameters, {'item_count': 3});
      },
    );

    test(
      'a day completed is remembered on the device for the account',
      () async {
        final first = build()..add(const TodayDayCompleted(3));
        await Future<void>.delayed(Duration.zero);
        expect(store.getString(TodayBloc.dayCompleteKey(uid)), '2026-03-14');
        await first.close();
        final again = build()..add(const TodayDayCompleted(3));
        await Future<void>.delayed(Duration.zero);
        expect(again.state.dayCompletions, 0);
        await again.close();
      },
    );

    test("the review card stays opened all week, under Swift's key", () async {
      final first = build()..add(const TodayWeeklyReviewOpened());
      await Future<void>.delayed(Duration.zero);
      expect(first.state.weeklyReviewOpened, isTrue);
      // The week starting Monday 9 March.
      expect(
        store.getString(TodayBloc.weeklyReviewOpenedKey(uid)),
        '2026-03-09',
      );
      await first.close();
      expect(build().state.weeklyReviewOpened, isTrue);
      store.setString(TodayBloc.weeklyReviewOpenedKey(uid), '2026-03-02');
      expect(build().state.weeklyReviewOpened, isFalse);
    });

    test("hiding getting started stays hidden, under Swift's key", () async {
      expect(build().state.starterDismissed, isFalse);
      final first = build()..add(const TodayStarterDismissed(3));
      await Future<void>.delayed(Duration.zero);
      expect(first.state.starterDismissed, isTrue);
      expect(store.getBool(TodayBloc.starterDismissedKey(uid)), isTrue);
      expect(
        tracked()
            .where((e) => e.eventName == 'TodayView_Starter_Dismiss')
            .single
            .parameters,
        {'remaining': 3},
      );
      await first.close();
      expect(build().state.starterDismissed, isTrue);
    });

    // `testTrainingItemRoutes`, `testSocialPulseTracked`: the bloc's part.
    blocTest<TodayBloc, TodayState>(
      'checklist taps and the social row are tracked',
      build: build,
      act: (bloc) => bloc
        ..add(const TodayChecklistItemPressed(TrainingItem()))
        ..add(
          const TodayChecklistItemPressed(
            NutritionItem(calories: 0, proteinGrams: 0, mealsLogged: 0),
          ),
        )
        ..add(const TodayChecklistItemPressed(WeighInItem(isToday: false)))
        ..add(const TodayChecklistItemPressed(StepsItem(today: 0, goal: 1)))
        ..add(const TodaySocialPulsePressed()),
      verify: (_) {
        final events = tracked();
        expect(
          [
            for (final e in events)
              if (e.eventName == 'TodayView_ChecklistItem_Press')
                e.parameters?['item'],
          ],
          ['training', 'nutrition', 'weighIn', 'steps'],
        );
        expect(events.last.eventName, 'TodayView_SocialPulse_Press');
      },
    );
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
    // Strava's step is the view's to add.
    expect(state.starterSteps, [
      StarterStep.firstWorkout,
      StarterStep.firstMeal,
      StarterStep.firstWeighIn,
      StarterStep.appleHealth,
    ]);
    expect(state.streak.state, StreakState.none);
  });
}
