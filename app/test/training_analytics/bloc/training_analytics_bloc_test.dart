import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/training_analytics/training_analytics.dart';
import 'package:compound_maths/compound_maths.dart' show VolumeAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
  // Saturday 14 March 2026, 6pm.
  final now = DateTime(2026, 3, 14, 18);

  final press = fixtureLibraryExercise(
    'press',
    name: 'Press',
    muscles: const {
      Muscles.sideDelts: MuscleTargetType.primary,
      Muscles.triceps: MuscleTargetType.secondary,
    },
  );

  WorkoutSessionModel lift(int day, double kg) => fixtureSession(
    'press-$day',
    day: day,
    author: uid,
    exercises: [
      fixtureExercise(
        'press',
        sets: [
          fixtureSet(weightKg: kg),
          fixtureSet(),
        ],
      ),
    ],
  );

  final sessions = [
    lift(13, 100),
    lift(6, 95),
    fixtureSession('rest', day: 12, author: uid, isRestDay: true),
    fixtureSession('friend', day: 12),
    fixtureSession('live', day: 14, author: uid, finished: false),
  ];

  late WorkoutSessionRepository workouts;
  late TrainingLibraryRepository library;
  late UserRepository users;
  late AnalyticsRepository analytics;

  setUpAll(() => registerFallbackValue(_FakeEvent()));

  setUp(() {
    workouts = MockWorkoutSessionRepository();
    library = _MockTrainingLibraryRepository();
    users = MockUserRepository();
    analytics = _MockAnalyticsRepository();
    when(() => workouts.watchSessions(uid))
        .thenAnswer((_) => Stream.value(sessions));
    when(() => library.watchUserExercises(uid))
        .thenAnswer((_) => Stream.value([press]));
    when(() => users.watchUser(uid)).thenAnswer(
      (_) => Stream.value(
        UserModel(
          userId: uid,
          submittedWeightUnitPreference: WeightUnitPreference.pounds,
          submittedDateOfBirth: DateTime(1990),
        ),
      ),
    );
  });

  TrainingAnalyticsBloc build({
    TrainingAnalyticsScreen screen = TrainingAnalyticsScreen.exercises,
    Map<String, Object?>? parameters,
  }) => TrainingAnalyticsBloc(
    workoutSessionRepository: workouts,
    trainingLibraryRepository: library,
    userRepository: users,
    analyticsRepository: analytics,
    uid: uid,
    screen: screen,
    parameters: parameters,
    now: () => now,
  );

  Matcher event(String name, [Map<String, Object?>? parameters]) =>
      isA<LoggableEvent>()
          .having((e) => e.eventName, 'eventName', name)
          .having((e) => e.parameters, 'parameters', parameters);

  group(TrainingAnalyticsBloc, () {
    test('opens loading', () {
      final state = build().state;
      expect(state.status, TrainingAnalyticsStatus.loading);
      expect(state.today, DateTime(2026, 3, 14));
      expect(state.range, MetricRange.week);
    });

    blocTest<TrainingAnalyticsBloc, TrainingAnalyticsState>(
      'derives every figure from the sessions, exercises and profile',
      build: () => build(
        screen: TrainingAnalyticsScreen.exerciseDetail,
        parameters: {'exercise_template_id': 'press'},
      ),
      act: (bloc) => bloc.add(const TrainingAnalyticsSubscriptionRequested()),
      verify: (bloc) {
        verify(
          () => analytics.trackScreenView(
            any(
              that: event('ExerciseDetailView_Appear', {
                'exercise_template_id': 'press',
              }),
            ),
          ),
        ).called(1);
        final state = bloc.state;
        expect(state.status, TrainingAnalyticsStatus.loaded);
        expect(state.usesPounds, isTrue);
        // Two finished workouts of the user's own, newest first.
        expect([for (final s in state.finished) s.id], ['press-13', 'press-6']);
        expect([for (final w in state.workouts) w.sets], [2, 2]);
        expect(state.workouts.first.volumeKg, 1000);
        expect(state.library.where((e) => e.id == 'press'), hasLength(1));
        expect(
          state.exerciseCardList.firstWhere((c) => c.id == 'press').bestKg,
          closeTo(116.67, 0.01),
        );
        expect(state.exerciseName('press'), 'Press');
        expect(state.exerciseName('system-barbell-squat'), 'Barbell Squat');
        expect(state.exerciseName('missing'), 'missing');
        expect(
          state.oneRepMaxPoints('press').last.value,
          closeTo(116.67 * 2.20462, 0.05),
        );
        expect(state.lastSevenDaysByMuscle[Muscles.sideDelts], [
          0,
          0,
          0,
          0,
          0,
          2,
          0,
        ]);
        expect(state.muscleSetPoints(Muscles.triceps), [
          (date: DateTime(2026, 3, 6), value: 1.0),
          (date: DateTime(2026, 3, 13), value: 1.0),
        ]);
        expect(state.weeklySetsByMuscle[Muscles.sideDelts]!.last, 2);
        expect(
          state.recommendation(Muscles.sideDelts).action,
          VolumeAction.needsMoreData,
        );
        expect(state.inUnit(1), closeTo(2.20462, 1e-9));
      },
    );

    blocTest<TrainingAnalyticsBloc, TrainingAnalyticsState>(
      "names an exercise as last logged when it isn't in the library",
      setUp: () =>
          when(() => library.watchUserExercises(uid))
              .thenAnswer((_) => Stream.value(const [])),
      build: build,
      act: (bloc) => bloc.add(const TrainingAnalyticsSubscriptionRequested()),
      verify: (bloc) => expect(bloc.state.exerciseName('press'), 'press'),
    );

    blocTest<TrainingAnalyticsBloc, TrainingAnalyticsState>(
      'fails when the sessions cannot be read',
      setUp: () =>
          when(() => workouts.watchSessions(uid))
              .thenAnswer((_) => Stream.error(Exception('offline'))),
      build: build,
      act: (bloc) => bloc.add(const TrainingAnalyticsSubscriptionRequested()),
      verify: (bloc) =>
          expect(bloc.state.status, TrainingAnalyticsStatus.failure),
    );

    blocTest<TrainingAnalyticsBloc, TrainingAnalyticsState>(
      'falls back when the exercises or profile cannot be read',
      setUp: () {
        when(() => library.watchUserExercises(uid))
            .thenAnswer((_) => Stream.error(Exception('exercises')));
        when(() => users.watchUser(uid))
            .thenAnswer((_) => Stream.error(Exception('user')));
      },
      build: build,
      act: (bloc) => bloc.add(const TrainingAnalyticsSubscriptionRequested()),
      verify: (bloc) {
        expect(bloc.state.status, TrainingAnalyticsStatus.loaded);
        expect(bloc.state.userExercises, isEmpty);
        expect(bloc.state.usesPounds, isFalse);
      },
    );

    blocTest<TrainingAnalyticsBloc, TrainingAnalyticsState>(
      'picks a range',
      build: build,
      act: (bloc) =>
          bloc.add(const TrainingAnalyticsRangeSelected(MetricRange.year)),
      expect: () => [
        isA<TrainingAnalyticsState>().having(
          (s) => s.range,
          'range',
          MetricRange.year,
        ),
      ],
    );

    blocTest<TrainingAnalyticsBloc, TrainingAnalyticsState>(
      'toggles a muscle, logging each press',
      build: () => build(screen: TrainingAnalyticsScreen.muscleBalance),
      act: (bloc) => bloc
        ..add(const TrainingAnalyticsMuscleToggled(Muscles.chest))
        ..add(const TrainingAnalyticsMuscleToggled(Muscles.chest)),
      expect: () => [
        isA<TrainingAnalyticsState>().having(
          (s) => s.selectedMuscle,
          'selectedMuscle',
          Muscles.chest,
        ),
        isA<TrainingAnalyticsState>().having(
          (s) => s.selectedMuscle,
          'selectedMuscle',
          isNull,
        ),
      ],
      verify: (_) => verify(
        () => analytics.trackEvent(
          any(
            that: event('MuscleBalanceView_Muscle_Press', {'muscle': 'chest'}),
          ),
        ),
      ).called(2),
    );
  });
}
