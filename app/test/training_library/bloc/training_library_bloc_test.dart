import 'package:bloc_test/bloc_test.dart';
import 'package:compound/training_library/training_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../../helpers/helpers.dart';

class _MockLibraryRepository extends Mock implements TrainingLibraryRepository;

class _MockProgramRepository extends Mock implements ProgramRepository;

void main() {
  late TrainingLibraryRepository library;
  late ProgramRepository programs;

  final exercise = fixtureLibraryExercise('bench');
  final template = fixtureTemplate('push');
  final mesocycle = fixtureMesocycle('m1', [template]);

  setUp(() {
    library = _MockLibraryRepository();
    programs = _MockProgramRepository();
    when(() => library.watchUserExercises('friend'))
        .thenAnswer((_) => Stream.value([exercise]));
    when(() => library.watchUserWorkoutTemplates('friend'))
        .thenAnswer((_) => Stream.value([template]));
    when(() => library.watchGymProfiles('friend'))
        .thenAnswer((_) => Stream.value(const []));
    when(() => programs.watchMesocycles('friend'))
        .thenAnswer((_) => Stream.value([mesocycle]));
  });

  TrainingLibraryBloc build() => TrainingLibraryBloc(
    libraryRepository: library,
    programRepository: programs,
    uid: 'friend',
  );

  group(TrainingLibraryBloc, () {
    test('starts loading', () {
      expect(build().state, const TrainingLibraryLoading());
    });

    blocTest<TrainingLibraryBloc, TrainingLibraryState>(
      'loads once every list has arrived',
      build: build,
      act: (bloc) => bloc.add(const TrainingLibrarySubscriptionRequested()),
      expect: () => [
        const TrainingLibraryLoading(),
        TrainingLibraryLoaded(
          TrainingLibrary(
            userExercises: [exercise],
            userWorkoutTemplates: [template],
            mesocycles: [mesocycle],
          ),
        ),
      ],
    );

    blocTest<TrainingLibraryBloc, TrainingLibraryState>(
      'fails when any list cannot be read, and stays failed',
      setUp: () =>
          when(() => programs.watchMesocycles('friend'))
              .thenAnswer((_) => Stream.error(Exception('offline'))),
      build: build,
      act: (bloc) => bloc.add(const TrainingLibrarySubscriptionRequested()),
      expect: () => [
        const TrainingLibraryLoading(),
        const TrainingLibraryFailure(),
      ],
    );
  });
}
