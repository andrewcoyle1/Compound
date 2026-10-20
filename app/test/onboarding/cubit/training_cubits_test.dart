import 'package:compound/onboarding/training/gym_setup_cubit.dart';
import 'package:compound/onboarding/training/program_setup_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';

import 'helpers.dart';

void main() {
  late MockTrainingSetupService service;
  late RecordingAnalytics analytics;
  final now = DateTime.utc(2026, 10, 15, 9);
  final programs = PrebuiltCatalogue.instance.mesocycles;

  setUpAll(() {
    registerFallbackValue(
      newGymProfile(authorId: '', name: '', now: now, weightUnit: null),
    );
    registerFallbackValue(programs.first);
  });

  setUp(() {
    service = MockTrainingSetupService();
    analytics = RecordingAnalytics();
  });

  group(GymSetupCubit, () {
    var ids = 0;
    GymSetupCubit build({WeightUnitPreference? unit}) => GymSetupCubit(
      analyticsRepository: analytics.repository,
      profile: UserModel(userId: 'uid', submittedWeightUnitPreference: unit),
      now: () => now,
      newId: () => 'ID-${ids++}',
      kilogramStackName: 'Pila en kilos',
    );

    setUp(() => ids = 0);

    test('a gym needs a name before it can be created', () {
      final cubit = build();
      expect(cubit.state.canSave, isFalse);
      expect(cubit.draft(), isNull);
      cubit.nameChanged('Home Gym');
      expect(cubit.state.canSave, isTrue);
      // Untrimmed, as Swift's canSave.
      expect((build()..nameChanged(' ')).state.canSave, isTrue);
    });

    test('the typed name carries into the new gym, with the catalogue for '
        "the user's unit", () {
      final draft = (build(
        unit: WeightUnitPreference.pounds,
      )..nameChanged('Home Gym')).draft()!;
      ids = 0;
      final expected = newGymProfile(
        authorId: 'uid',
        name: 'Home Gym',
        now: now,
        weightUnit: WeightUnitPreference.pounds,
        newId: () => 'ID-${ids++}',
        kilogramStackName: 'Pila en kilos',
      );
      expect(draft.toFirestore(), expected.toFirestore());
      expect(draft.authorId, 'uid');
      verifyZeroInteractions(service);
    });

    test('appearing is tracked as a screen view, and leaving', () async {
      final cubit = build();
      expect(analytics.names, ['CreateGymProfileView_Appear']);
      await cubit.close();
      expect(analytics.names.last, 'CreateGymProfileView_Disappear');
    });
  });

  group(ProgramSetupCubit, () {
    ProgramSetupCubit build(ExerciseFrequency? frequency) => ProgramSetupCubit(
      trainingSetupService: service,
      analyticsRepository: analytics.repository,
      profile: UserModel(userId: 'uid', submittedExerciseFrequency: frequency),
      programs: programs,
    );

    setUp(
      () => when(() => service.startPrebuiltMesocycle(any(), any())).thenAnswer(
        (invocation) async => invocation.positionalArguments.last as Mesocycle,
      ),
    );

    test('recommends by frequency, the rest fewest workouts first', () {
      final cubit = build(ExerciseFrequency.threeToFour);
      expect(cubit.state.recommended?.id, 'program-upper-lower');
      expect(cubit.state.selectedId, 'program-upper-lower');
      expect(
        [for (final program in cubit.state.others) program.id],
        ['program-full-body', 'program-531', 'program-push-pull-legs'],
      );
      expect([
        for (final p in cubit.state.others) workoutsPerMicrocycle(p),
      ], orderedEquals([3, 4, 6]));
    });

    test('without a frequency nothing is recommended or chosen', () {
      final cubit = build(null);
      expect(cubit.state.recommended, isNull);
      expect(cubit.state.selected, isNull);
      expect(cubit.state.others, hasLength(programs.length));
    });

    test('choosing logs it, and Start starts the choice', () async {
      final cubit = build(ExerciseFrequency.daily);
      final fullBody = programs.firstWhere((p) => p.id == 'program-full-body');
      cubit.programSelected(fullBody);
      expect(cubit.state.selected, fullBody);
      await cubit.start();
      verify(() => service.startPrebuiltMesocycle('uid', fullBody)).called(1);
      expect(cubit.state.status, ProgramSetupStatus.started);
      expect(analytics.last('CreateProgramView_Program_Pressed').parameters, {
        'program_id': 'program-full-body',
        'is_recommended': false,
      });
      expect(analytics.names.sublist(1), [
        'CreateProgramView_Program_Pressed',
        'PrebuiltProgramDetailView_Start_Start',
        'PrebuiltProgramDetailView_Start_Success',
      ]);
      await cubit.start();
      verifyNever(() => service.startPrebuiltMesocycle(any(), any()));
    });

    test('a failed start says so', () async {
      when(() => service.startPrebuiltMesocycle(any(), any()))
          .thenThrow(Exception('offline'));
      final cubit = build(ExerciseFrequency.daily);
      await cubit.start();
      expect(cubit.state.status, ProgramSetupStatus.failure);
      expect(
        analytics
            .last('PrebuiltProgramDetailView_Start_Fail')
            .parameters?['program_id'],
        'program-push-pull-legs',
      );
      await cubit.close();
      expect(analytics.names.last, 'CreateProgramView_Disappear');
    });

    test('start does nothing with nothing chosen', () async {
      await build(null).start();
      verifyZeroInteractions(service);
    });
  });
}
