import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/weekly_review/weekly_review.dart';
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

  late WorkoutSessionRepository workouts;
  late NutritionRepository nutrition;
  late BodyRepository body;
  late TrainingLibraryRepository library;
  late UserRepository users;
  late AnalyticsRepository analytics;

  setUpAll(() => registerFallbackValue(_FakeEvent()));

  setUp(() {
    workouts = MockWorkoutSessionRepository();
    nutrition = MockNutritionRepository();
    body = MockBodyRepository();
    library = _MockTrainingLibraryRepository();
    users = MockUserRepository();
    analytics = _MockAnalyticsRepository();
    when(() => workouts.watchSessions(uid)).thenAnswer(
      (_) => Stream.value([
        fixtureSession('a', day: 10, author: uid),
        fixtureSession('b', day: 11, author: uid),
      ]),
    );
    when(() => nutrition.watchMeals(uid))
        .thenAnswer((_) => Stream.value(const []));
    when(() => nutrition.watchDietPlan(uid))
        .thenAnswer((_) => Stream.value(null));
    when(() => body.watchMeasurements(uid))
        .thenAnswer((_) => Stream.value(const []));
    when(() => library.watchUserExercises(uid))
        .thenAnswer((_) => Stream.value([fixtureLibraryExercise('bench')]));
    when(() => users.watchUser(uid)).thenAnswer(
      (_) => Stream.value(
        const UserModel(
          userId: uid,
          weeklySessionGoal: 2,
          submittedWeightUnitPreference: WeightUnitPreference.pounds,
        ),
      ),
    );
  });

  // Wednesday 11 March 2026; the week starts on Monday (1).
  WeeklyReviewBloc build({DateTime? now}) => WeeklyReviewBloc(
    workoutSessionRepository: workouts,
    nutritionRepository: nutrition,
    bodyRepository: body,
    trainingLibraryRepository: library,
    userRepository: users,
    analyticsRepository: analytics,
    uid: uid,
    firstDayOfWeek: 1,
    now: () => now ?? DateTime(2026, 3, 11, 18),
  );

  group(WeeklyReviewBloc, () {
    test('opens on last week on its first day, this week otherwise', () {
      final monday = build(now: DateTime(2026, 3, 16, 9)).state;
      expect(monday.weekStart, DateTime(2026, 3, 9));
      expect(monday.canShowNextWeek, isTrue);
      final wednesday = build().state;
      expect(wednesday.weekStart, DateTime(2026, 3, 9));
      expect(wednesday.canShowNextWeek, isFalse);
      expect(wednesday.status, WeeklyReviewStatus.loading);
    });

    blocTest<WeeklyReviewBloc, WeeklyReviewState>(
      "reads the user's data and goal",
      build: build,
      act: (bloc) => bloc.add(const WeeklyReviewSubscriptionRequested()),
      verify: (bloc) {
        verify(
          () => analytics.trackScreenView(
            any(
              that: isA<LoggableEvent>().having(
                (e) => e.eventName,
                'eventName',
                'WeeklyReviewView_Appear',
              ),
            ),
          ),
        ).called(1);
        final state = bloc.state;
        expect(state.status, WeeklyReviewStatus.loaded);
        expect(state.usesPounds, isTrue);
        final review = state.review((m) => m.name);
        expect(review.sessionCount, 2);
        expect(review.goal, 2);
        expect(review.takeaway, const GoalHitTakeaway(2, 2));
      },
    );

    blocTest<WeeklyReviewBloc, WeeklyReviewState>(
      'fails when the sessions, meals or weigh-ins cannot be read',
      setUp: () =>
          when(() => nutrition.watchMeals(uid))
              .thenAnswer((_) => Stream.error(Exception('offline'))),
      build: build,
      act: (bloc) => bloc.add(const WeeklyReviewSubscriptionRequested()),
      verify: (bloc) => expect(bloc.state.status, WeeklyReviewStatus.failure),
    );

    blocTest<WeeklyReviewBloc, WeeklyReviewState>(
      'falls back when the niceties cannot be read',
      setUp: () {
        when(() => nutrition.watchDietPlan(uid))
            .thenAnswer((_) => Stream.error(Exception('plan')));
        when(() => library.watchUserExercises(uid))
            .thenAnswer((_) => Stream.error(Exception('exercises')));
        when(() => users.watchUser(uid))
            .thenAnswer((_) => Stream.error(Exception('user')));
      },
      build: build,
      act: (bloc) => bloc.add(const WeeklyReviewSubscriptionRequested()),
      verify: (bloc) {
        final state = bloc.state;
        expect(state.status, WeeklyReviewStatus.loaded);
        expect(state.review((m) => m.name).goal, 3);
      },
    );

    blocTest<WeeklyReviewBloc, WeeklyReviewState>(
      'navigation stops at the current week',
      build: build,
      act: (bloc) => bloc
        ..add(const WeeklyReviewNextWeekPressed())
        ..add(const WeeklyReviewPreviousWeekPressed())
        ..add(const WeeklyReviewNextWeekPressed()),
      expect: () => [
        isA<WeeklyReviewState>().having(
          (s) => s.weekStart,
          'weekStart',
          DateTime(2026, 3, 2),
        ),
        isA<WeeklyReviewState>().having(
          (s) => s.weekStart,
          'weekStart',
          DateTime(2026, 3, 9),
        ),
      ],
    );
  });
}
