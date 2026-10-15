import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart' show AppWeightUnit;
import 'package:bloc_test/bloc_test.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/progress/logic/progress_overview.dart';
import 'package:compound/progress/progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository;

class _MockTrainingLibraryRepository extends Mock
    implements TrainingLibraryRepository;

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

  BodyMeasurementEntry weighIn(DateTime date, double kg, {double? bodyFat}) =>
      BodyMeasurementEntry(
        id: 'w-$kg',
        authorId: uid,
        weightKg: kg,
        bodyFatPercentage: bodyFat,
        date: date,
        source: WeightSource.manual,
        dateCreated: date,
      );

  final goal = WeightGoal(
    goalId: uid,
    userId: uid,
    objective: OverarchingObjective.loseWeight,
    startingWeightKg: 82,
    targetWeightKg: 78,
    weeklyChangeKg: 0.5,
    createdAt: DateTime(2026, 3),
    status: GoalStatus.active,
  );

  final sessions = [
    for (final day in [9, 10, 12])
      fixtureSession('s$day', day: day, author: uid),
    fixtureSession('rest', day: 11, author: uid, isRestDay: true),
    fixtureSession('live', day: 14, author: uid, finished: false),
    for (final day in [2, 4, 6]) fixtureSession('p$day', day: day, author: uid),
  ];

  late WorkoutSessionRepository workoutSessionRepository;
  late NutritionRepository nutritionRepository;
  late BodyRepository bodyRepository;
  late UserRepository userRepository;
  late AnalyticsRepository analyticsRepository;
  late TrainingLibraryRepository trainingLibraryRepository;

  setUpAll(() => registerFallbackValue(_FakeEvent()));

  setUp(() {
    workoutSessionRepository = MockWorkoutSessionRepository();
    nutritionRepository = MockNutritionRepository();
    bodyRepository = MockBodyRepository();
    userRepository = MockUserRepository();
    analyticsRepository = _MockAnalyticsRepository();
    trainingLibraryRepository = _MockTrainingLibraryRepository();
    when(() => trainingLibraryRepository.watchUserExercises(uid)).thenAnswer(
      (_) => Stream.value([
        fixtureLibraryExercise(
          'press',
          muscles: const {
            Muscles.sideDelts: MuscleTargetType.primary,
            Muscles.triceps: MuscleTargetType.secondary,
          },
        ),
      ]),
    );
    when(() => workoutSessionRepository.watchSessions(uid))
        .thenAnswer((_) => Stream.value(sessions));
    when(() => nutritionRepository.watchMeals(uid))
        .thenAnswer((_) => Stream.value([meal('a'), meal('b')]));
    when(() => nutritionRepository.watchDietPlan(uid))
        .thenAnswer((_) => Stream.value(plan()));
    when(() => bodyRepository.watchMeasurements(uid)).thenAnswer(
      (_) => Stream.value([
        weighIn(DateTime(2026, 3, 6, 7), 81),
        weighIn(DateTime(2026, 3, 14, 7), 80, bodyFat: 18.4),
      ]),
    );
    when(() => bodyRepository.watchSteps(uid)).thenAnswer(
      (_) => Stream.value([
        StepsModel(
          id: 'steps',
          authorId: uid,
          number: 9000,
          date: DateTime(2026, 3, 14, 9),
          source: StepsSource.healthkit,
          dateCreated: now,
          dateModified: now,
        ),
      ]),
    );
    when(() => bodyRepository.watchAnalyticsSettings(uid)).thenAnswer(
      (_) => Stream.value(
        const AnalyticsSettings(authorId: uid, hiddenSectionIds: ['habits']),
      ),
    );
    when(() => userRepository.watchUser(uid)).thenAnswer(
      (_) => Stream.value(
        const UserModel(
          userId: uid,
          submittedWeightUnitPreference: WeightUnitPreference.pounds,
        ),
      ),
    );
    when(
      () => bodyRepository.watchCurrentGoal(
        uid,
        currentGoalId: any(named: 'currentGoalId'),
      ),
    ).thenAnswer((_) => Stream.value(goal));
  });

  ProgressBloc build() => ProgressBloc(
    workoutSessionRepository: workoutSessionRepository,
    nutritionRepository: nutritionRepository,
    bodyRepository: bodyRepository,
    userRepository: userRepository,
    analyticsRepository: analyticsRepository,
    trainingLibraryRepository: trainingLibraryRepository,
    checkInRepository: InMemoryCheckInRepository(),
    uid: uid,
    firstWeekday: DateTime.monday,
    now: () => now,
  );

  group(ProgressBloc, () {
    test('opens loading', () {
      final state = build().state;
      expect(state.status, ProgressStatus.loading);
      expect(state.now, now);
      expect(state.uid, uid);
    });

    blocTest<ProgressBloc, ProgressState>(
      'builds the cards from every repository',
      build: build,
      act: (bloc) => bloc.add(const ProgressSubscriptionRequested()),
      verify: (bloc) {
        final state = bloc.state;
        verify(
          () => analyticsRepository.trackScreenView(
            any(
              that: isA<LoggableEvent>().having(
                (e) => e.eventName,
                'eventName',
                'AnalyticsView_Appear',
              ),
            ),
          ),
        ).called(1);
        expect(state.status, ProgressStatus.loaded);
        expect(state.unit, AppWeightUnit.pounds);
        expect(state.goal, goal);
        expect(state.isVisible(ProgressSection.habits), isFalse);
        expect(state.isVisible(ProgressSection.nutrition), isTrue);

        // Six finished workouts, no rest day, nothing in progress.
        expect(
          [for (final s in state.recentWorkouts) s.id],
          ['p2', 'p4', 'p6', 's9', 's10', 's12'],
        );
        expect(state.workoutSets.every((p) => p.value == 0), isTrue);
        expect(state.workoutsThisWeek, 3);
        expect(state.workoutGrid.where((d) => d), hasLength(6));
        expect(state.weighInsThisWeek, 1);
        expect(state.weighInGrid.last, isTrue);

        expect(state.macrosWeek.last.calories, 1000);
        expect(state.macrosWeek.last.proteinGrams, 80);
        expect(state.proteinTarget, 150);

        expect(state.scaleWeights.map((p) => p.value), [
          closeTo(81 * 2.20462, 1e-9),
          closeTo(80 * 2.20462, 1e-9),
        ]);
        expect(state.trendWeights, hasLength(2));
        expect(state.bodyFat.single.value, 18.4);
        expect(state.stepsWeek.single.value, 9000);
        expect(state.goalProgress.state, GoalProgressState.measured);
      },
    );

    blocTest<ProgressBloc, ProgressState>(
      'fails when the sessions, meals or weigh-ins cannot be read',
      setUp: () =>
          when(() => bodyRepository.watchMeasurements(uid))
              .thenAnswer((_) => Stream.error(Exception('offline'))),
      build: build,
      act: (bloc) => bloc.add(const ProgressSubscriptionRequested()),
      verify: (bloc) => expect(bloc.state.status, ProgressStatus.failure),
    );

    blocTest<ProgressBloc, ProgressState>(
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
        when(() => trainingLibraryRepository.watchUserExercises(uid))
            .thenAnswer((_) => Stream.error(Exception('exercises')));
        when(
          () => bodyRepository.watchCurrentGoal(
            uid,
            currentGoalId: any(named: 'currentGoalId'),
          ),
        ).thenAnswer((_) => Stream.error(Exception('goal')));
      },
      build: build,
      act: (bloc) => bloc.add(const ProgressSubscriptionRequested()),
      verify: (bloc) {
        final state = bloc.state;
        expect(state.status, ProgressStatus.loaded);
        expect(state.dietPlan, isNull);
        expect(state.proteinTarget, isNull);
        expect(state.goal, isNull);
        expect(state.goalProgress.state, GoalProgressState.noGoal);
        expect(state.unit, AppWeightUnit.kilograms);
        expect(state.steps, isEmpty);
        expect(state.isVisible(ProgressSection.habits), isTrue);
        expect(state.userExercises, isEmpty);
      },
    );

    blocTest<ProgressBloc, ProgressState>(
      'ranks the muscles and lifts of the training cards',
      setUp: () =>
          when(() => workoutSessionRepository.watchSessions(uid)).thenAnswer(
            (_) => Stream.value([
              fixtureSession(
                'press-day',
                day: 13,
                author: uid,
                exercises: [
                  fixtureExercise(
                    'press',
                    sets: [fixtureSet(), fixtureSet(weightKg: 60)],
                  ),
                ],
              ),
            ]),
          ),
      build: build,
      act: (bloc) => bloc.add(const ProgressSubscriptionRequested()),
      verify: (bloc) {
        final state = bloc.state;
        final week = state.muscleLastSevenDays;
        expect(week[Muscles.sideDelts], [0, 0, 0, 0, 0, 2, 0]);
        expect(week[Muscles.triceps]![5], 1);
        final top = state.topExercises;
        expect(top, hasLength(2));
        expect(top.first.id, 'press');
        // 100 kg × 5: Epley 100 × (1 + 5/30).
        expect(top.first.bestKg, closeTo(116.667, 1e-3));
      },
    );

    blocTest<ProgressBloc, ProgressState>(
      'follows the goal the profile names',
      setUp: () {
        when(() => userRepository.watchUser(uid)).thenAnswer(
          (_) => Stream.value(
            const UserModel(userId: uid, submittedCurrentGoalId: 'g2'),
          ),
        );
        when(() => bodyRepository.watchCurrentGoal(uid, currentGoalId: 'g2'))
            .thenAnswer((_) => const Stream.empty());
      },
      build: build,
      act: (bloc) => bloc.add(const ProgressSubscriptionRequested()),
      verify: (_) => verify(
        () => bodyRepository.watchCurrentGoal(uid, currentGoalId: 'g2'),
      ).called(1),
    );
  });
}
