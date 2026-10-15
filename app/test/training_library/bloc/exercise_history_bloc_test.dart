import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/training_library/training_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository;

void main() {
  late WorkoutSessionRepository repository;
  late AnalyticsRepository analytics;

  final session = fixtureSession(
    'a',
    exercises: [
      fixtureExercise('Bench', sets: [fixtureSet()]),
    ],
  );

  setUpAll(() => registerFallbackValue(const AnalyticsEvent('fallback')));

  setUp(() {
    repository = MockWorkoutSessionRepository();
    analytics = _MockAnalyticsRepository();
  });

  ExerciseHistoryBloc build() => ExerciseHistoryBloc(
    repository: repository,
    uid: 'friend',
    exerciseId: 'Bench',
    analytics: analytics,
  );

  group(ExerciseHistoryBloc, () {
    test('starts loading', () {
      expect(build().state, const ExerciseHistoryLoading());
    });

    blocTest<ExerciseHistoryBloc, ExerciseHistoryState>(
      "follows the exercise's sessions and tracks the screen",
      setUp: () =>
          when(() => repository.watchSessions('friend'))
              .thenAnswer((_) => Stream.value([session])),
      build: build,
      act: (bloc) => bloc.add(const ExerciseHistorySubscriptionRequested()),
      expect: () => [
        const ExerciseHistoryLoading(),
        ExerciseHistoryLoaded(ExerciseDetailStats.make([session], 'Bench')),
      ],
      verify: (_) {
        final event =
            verify(() => analytics.trackScreenView(captureAny()))
                    .captured
                    .single
                as AnalyticsEvent;
        expect(event.eventName, 'ExerciseModelDetailView_Appear');
        expect(event.parameters, {'exercise_id': 'Bench'});
      },
    );

    blocTest<ExerciseHistoryBloc, ExerciseHistoryState>(
      'fails when the sessions cannot be read',
      setUp: () =>
          when(() => repository.watchSessions('friend'))
              .thenAnswer((_) => Stream.error(Exception('offline'))),
      build: build,
      act: (bloc) => bloc.add(const ExerciseHistorySubscriptionRequested()),
      expect: () => [
        const ExerciseHistoryLoading(),
        const ExerciseHistoryFailure(),
      ],
    );
  });
}
