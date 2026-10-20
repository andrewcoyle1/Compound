import 'package:bloc_test/bloc_test.dart';
import 'package:compound/programs/cubit/workout_preview_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';
import '../helpers.dart';

/// A library whose gyms cannot be read.
class _BrokenLibrary extends InMemoryTrainingLibraryRepository {
  @override
  Stream<List<GymProfileModel>> watchGymProfiles(String uid) =>
      Stream.error(StateError('unreadable'));
}

void main() {
  late AnalyticsRecorder analytics;

  setUp(() => analytics = AnalyticsRecorder());

  WorkoutPreviewCubit build({TrainingLibraryRepository? library}) =>
      WorkoutPreviewCubit(
        library: library ?? InMemoryTrainingLibraryRepository(),
        sessions: InMemoryWorkoutSessionRepository(sessions: const []),
        users: InMemoryUserRepository(),
        analytics: analytics,
        clock: () => programNow,
      );

  blocTest<WorkoutPreviewCubit, WorkoutSessionModel?>(
    "builds the day's session, cut in a deload",
    build: build,
    act: (cubit) => cubit.load(
      programUid,
      programDays.first,
      mesocycleId: 'm1',
      microcycleIndex: 2,
      isDeload: true,
    ),
    verify: (cubit) {
      expect(cubit.state?.isDeload, isTrue);
      expect(cubit.state?.mesocycleId, 'm1');
      expect(cubit.state?.exercises.single.name, 'Bench');
    },
  );

  blocTest<WorkoutPreviewCubit, WorkoutSessionModel?>(
    'builds a plain session outside a deload',
    build: build,
    act: (cubit) => cubit.load(programUid, programDays.first),
    verify: (cubit) => expect(cubit.state?.isDeload, isNull),
  );

  blocTest<WorkoutPreviewCubit, WorkoutSessionModel?>(
    'a read that fails leaves no preview and says so',
    build: () => build(library: _BrokenLibrary()),
    act: (cubit) => cubit.load(programUid, programDays.first),
    expect: () => <WorkoutSessionModel?>[],
    verify: (_) =>
        expect(analytics.names, ['TodaysWorkoutCard_LoadTargets_Fail']),
  );
}
