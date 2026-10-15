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
      trainingSetupService: service,
      analyticsRepository: analytics.repository,
      profile: UserModel(userId: 'uid', submittedWeightUnitPreference: unit),
      now: () => now,
      newId: () => 'ID-${ids++}',
      untitledName: 'Gimnasio sin nombre',
      kilogramStackName: 'Pila en kilos',
    );

    setUp(() {
      ids = 0;
      when(
        () => service.saveGymProfile(
          any(),
          untitledName: any(named: 'untitledName'),
        ),
      ).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments.single as GymProfileModel,
      );
      when(() => service.setFavouriteGymProfile(any(), any()))
          .thenAnswer((_) async {});
    });

    test('saves a new gym with the catalogue for the user unit, then makes '
        'it the usual one', () async {
      final cubit = build(unit: WeightUnitPreference.pounds)
        ..nameChanged('Home');
      await cubit.save();

      final saved =
          verify(
                () => service.saveGymProfile(
                  captureAny(),
                  untitledName: 'Gimnasio sin nombre',
                ),
              ).captured.single
              as GymProfileModel;
      ids = 0;
      final expected = newGymProfile(
        authorId: 'uid',
        name: 'Home',
        now: now,
        weightUnit: WeightUnitPreference.pounds,
        newId: () => 'ID-${ids++}',
        kilogramStackName: 'Pila en kilos',
      );
      expect(saved.toFirestore(), expected.toFirestore());
      verify(() => service.setFavouriteGymProfile('uid', 'ID-0')).called(1);
      expect(cubit.state.status, GymSetupStatus.saved);
      expect(analytics.names, [
        'CreateGymProfileView_Appear',
        'GymProfileView_Save_Start',
        'GymProfileView_Save_Success',
        'GymProfileView_FavouriteGymProfile_Start',
        'GymProfileView_FavouriteGymProfile_Success',
      ]);
      await cubit.save();
      verifyNever(
        () => service.saveGymProfile(
          any(),
          untitledName: any(named: 'untitledName'),
        ),
      );
    });

    test('needs a name', () async {
      final cubit = build();
      await cubit.save();
      expect(cubit.state.canSave, isFalse);
      verifyZeroInteractions(service);
    });

    test('a failed save says so and makes nothing usual', () async {
      when(
        () => service.saveGymProfile(
          any(),
          untitledName: any(named: 'untitledName'),
        ),
      ).thenThrow(Exception('offline'));
      final cubit = build()..nameChanged('Home');
      await cubit.save();
      expect(cubit.state.status, GymSetupStatus.failure);
      verifyNever(() => service.setFavouriteGymProfile(any(), any()));
      expect(analytics.names.last, 'GymProfileView_Save_Fail');
    });

    test(
      'a failed favourite is logged and passed over, as Swift does',
      () async {
        when(() => service.setFavouriteGymProfile(any(), any()))
            .thenThrow(Exception('offline'));
        final cubit = build()..nameChanged('Home');
        await cubit.save();
        expect(cubit.state.status, GymSetupStatus.saved);
        expect(
          analytics.last('GymProfileView_FavouriteGymProfile_Fail').parameters,
          isNull,
        );
        await cubit.close();
        expect(analytics.names.last, 'CreateGymProfileView_Disappear');
      },
    );
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
