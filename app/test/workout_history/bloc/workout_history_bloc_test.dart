import 'package:bloc_test/bloc_test.dart';
import 'package:compound/workout_history/workout_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  late WorkoutSessionRepository repository;

  setUp(() => repository = MockWorkoutSessionRepository());

  WorkoutHistoryBloc build() => WorkoutHistoryBloc(
    repository: repository,
    uid: 'friend',
    firstDayOfWeek: 1,
  );

  final monday = fixtureSession(
    'mon',
    exercises: [
      fixtureExercise('Bench', sets: [fixtureSet(weightKg: 90)]),
    ],
  );
  final wednesday = fixtureSession(
    'wed',
    day: 4,
    weekStreakCount: 3,
    exercises: [
      fixtureExercise('Bench', sets: [fixtureSet()]),
    ],
  );
  final rest = fixtureSession('rest', day: 3, isRestDay: true);
  final running = fixtureSession('running', day: 5, finished: false);

  group(WorkoutHistoryBloc, () {
    test('starts loading', () {
      expect(build().state, const WorkoutHistoryLoading());
    });

    blocTest<WorkoutHistoryBloc, WorkoutHistoryState>(
      'lists finished, non-rest workouts newest first, with highlights',
      setUp: () => when(() => repository.watchSessions('friend'))
          .thenAnswer((_) => Stream.value([monday, rest, running, wednesday])),
      build: build,
      act: (bloc) => bloc.add(const WorkoutHistorySubscriptionRequested()),
      expect: () => [
        const WorkoutHistoryLoading(),
        WorkoutHistoryLoaded([
          WorkoutHistoryEntry(
            session: wednesday,
            personalRecords: const [
              PersonalRecord(
                exerciseName: 'Bench',
                trackingMode: TrackingMode.weightReps,
                value: 100,
                reps: 5,
                weightUnit: ExerciseWeightUnit.kilograms,
              ),
            ],
            weeklyWorkoutNumber: 2,
          ),
          WorkoutHistoryEntry(
            session: monday,
            personalRecords: const [],
            weeklyWorkoutNumber: 1,
          ),
        ]),
      ],
    );

    blocTest<WorkoutHistoryBloc, WorkoutHistoryState>(
      'fails when the sessions cannot be read, and tries again',
      setUp: () {
        var calls = 0;
        when(() => repository.watchSessions('friend')).thenAnswer(
          (_) => calls++ == 0
              ? Stream.error(Exception('offline'))
              : Stream.value(const []),
        );
      },
      build: build,
      act: (bloc) async {
        bloc.add(const WorkoutHistorySubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const WorkoutHistorySubscriptionRequested());
      },
      expect: () => const [
        WorkoutHistoryLoading(),
        WorkoutHistoryFailure(),
        WorkoutHistoryLoading(),
        WorkoutHistoryLoaded([]),
      ],
    );
  });
}
