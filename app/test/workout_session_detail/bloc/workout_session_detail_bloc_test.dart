import 'package:bloc_test/bloc_test.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  late WorkoutSessionRepository sessions;
  late UserRepository users;
  final session = fixtureSession('s');

  setUp(() {
    sessions = MockWorkoutSessionRepository();
    users = MockUserRepository();
  });

  WorkoutSessionDetailBloc build() => WorkoutSessionDetailBloc(
    sessionRepository: sessions,
    userRepository: users,
    uid: 'friend',
    sessionId: 's',
  );

  group(WorkoutSessionDetailBloc, () {
    test('starts loading', () {
      expect(build().state, const WorkoutSessionDetailLoading());
    });

    blocTest<WorkoutSessionDetailBloc, WorkoutSessionDetailState>(
      'shows the workout in the profile units',
      setUp: () {
        when(() => sessions.session('friend', 's'))
            .thenAnswer((_) async => session);
        when(() => users.watchUser('friend')).thenAnswer(
          (_) => Stream.value(
            const UserModel(
              userId: 'friend',
              submittedWeightUnitPreference: WeightUnitPreference.pounds,
              submittedDistanceUnitPreference: DistanceUnitPreference.miles,
            ),
          ),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const WorkoutSessionDetailRequested()),
      expect: () => [
        const WorkoutSessionDetailLoading(),
        WorkoutSessionDetailLoaded(
          session: session,
          weightUnit: WeightUnitPreference.pounds,
          distanceUnit: DistanceUnitPreference.miles,
        ),
      ],
    );

    blocTest<WorkoutSessionDetailBloc, WorkoutSessionDetailState>(
      'shows the workout in metric when the profile cannot be read',
      setUp: () {
        when(() => sessions.session('friend', 's'))
            .thenAnswer((_) async => session);
        when(() => users.watchUser('friend'))
            .thenAnswer((_) => Stream.error(Exception('offline')));
      },
      build: build,
      act: (bloc) => bloc.add(const WorkoutSessionDetailRequested()),
      expect: () => [
        const WorkoutSessionDetailLoading(),
        WorkoutSessionDetailLoaded(session: session),
      ],
    );

    blocTest<WorkoutSessionDetailBloc, WorkoutSessionDetailState>(
      'says when there is no such workout',
      setUp: () =>
          when(() => sessions.session('friend', 's'))
              .thenAnswer((_) async => null),
      build: build,
      act: (bloc) => bloc.add(const WorkoutSessionDetailRequested()),
      expect: () => const [
        WorkoutSessionDetailLoading(),
        WorkoutSessionDetailNotFound(),
      ],
    );

    blocTest<WorkoutSessionDetailBloc, WorkoutSessionDetailState>(
      'fails when the workout cannot be read',
      setUp: () =>
          when(() => sessions.session('friend', 's'))
              .thenThrow(Exception('offline')),
      build: build,
      act: (bloc) => bloc.add(const WorkoutSessionDetailRequested()),
      expect: () => const [
        WorkoutSessionDetailLoading(),
        WorkoutSessionDetailFailure(),
      ],
    );
  });
}
