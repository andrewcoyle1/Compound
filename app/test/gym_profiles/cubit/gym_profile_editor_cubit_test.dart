import 'package:compound/gym_profiles/cubit/gym_profile_editor_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../../onboarding/cubit/helpers.dart';

/// Swift `GymProfilePresenterTests`, for what the cubit holds: saving on
/// leaving and on Continue, and the machine edits. The listing rules are
/// `GymEditorRules`' tests in training_library_repository.
void main() {
  const latPulldown = 'cable_lat_pulldown_machine';
  final now = DateTime.utc(2026, 10, 16, 9);
  late MockTrainingSetupService setup;
  late RecordingAnalytics analytics;
  late GymProfileModel gym;

  setUpAll(() {
    registerFallbackValue(
      newGymProfile(authorId: '', name: '', now: now, weightUnit: null),
    );
  });

  setUp(() {
    setup = MockTrainingSetupService();
    analytics = RecordingAnalytics();
    gym = newGymProfile(
      authorId: 'author-1',
      name: 'Home Gym',
      now: now,
      weightUnit: null,
      newId: () => 'gym-1',
    );
    when(
      () =>
          setup.saveGymProfile(any(), untitledName: any(named: 'untitledName')),
    ).thenAnswer(
      (invocation) async =>
          invocation.positionalArguments.single as GymProfileModel,
    );
    when(() => setup.setFavouriteGymProfile(any(), any()))
        .thenAnswer((_) async {});
  });

  var ids = 0;
  GymProfileEditorCubit build() => GymProfileEditorCubit(
    gym: gym,
    uid: 'user-1',
    setup: setup,
    analytics: analytics.repository,
    untitledName: 'Gimnasio sin nombre',
    newId: () => 'new-${ids++}',
  );

  List<GymProfileModel> saved() => verify(
    () =>
        setup.saveGymProfile(captureAny(), untitledName: 'Gimnasio sin nombre'),
  ).captured.cast<GymProfileModel>();

  group('leaving the screen', () {
    test('leaving an edited profile saves it', () async {
      final cubit = build()..renamed('Garage Gym');
      expect(await cubit.left(), isTrue);
      expect([for (final gym in saved()) gym.name], ['Garage Gym']);
      expect(cubit.state.hasUnsavedChanges, isFalse);
    });

    test('leaving an untouched profile saves nothing', () async {
      final cubit = build();
      expect(cubit.state.hasUnsavedChanges, isFalse);
      expect(await cubit.left(), isNull);
      verifyNever(
        () => setup.saveGymProfile(
          any(),
          untitledName: any(named: 'untitledName'),
        ),
      );
    });

    test('an unnamed profile is saved under the untitled name', () async {
      await (build()..renamed('  ')).left();
      // The service puts the untitled name in (gymProfileToSave).
      expect(saved().single.name, '  ');
    });

    test('saving is tracked from start to success', () async {
      final cubit = build();
      analytics.events.clear();
      cubit.renamed('Garage Gym');
      await cubit.left();
      expect(analytics.names, [
        'GymProfileView_OnDisappear',
        'GymProfileView_Save_Start',
        'GymProfileView_Save_Success',
      ]);
    });

    test(
      'a failed save on leaving is reported, and the edit stays unsaved',
      () async {
        when(
          () => setup.saveGymProfile(
            any(),
            untitledName: any(named: 'untitledName'),
          ),
        ).thenThrow(Exception('offline'));
        final cubit = build()..renamed('Garage Gym');
        expect(await cubit.left(), isFalse);
        expect(analytics.names.last, 'GymProfileView_Save_Fail');
        expect(cubit.state.hasUnsavedChanges, isTrue);
      },
    );

    test('a save finishing after the screen closed changes nothing', () async {
      final cubit = build()..renamed('Garage Gym');
      final leaving = cubit.left();
      await cubit.close();
      expect(await leaving, isTrue);
    });
  });

  group('Continue', () {
    test('saves the profile and makes it the favourite', () async {
      final cubit = build();
      await cubit.continuePressed();
      expect(saved(), hasLength(1));
      verify(() => setup.setFavouriteGymProfile('user-1', 'gym-1')).called(1);
      expect(cubit.state.status, GymProfileEditorStatus.continued);
      expect(analytics.names, [
        'GymProfileView_OnAppear',
        'GymProfileView_Save_Start',
        'GymProfileView_Save_Success',
        'GymProfileView_FavouriteGymProfile_Start',
        'GymProfileView_FavouriteGymProfile_Success',
      ]);
      // Once only.
      await cubit.continuePressed();
      verifyNever(() => setup.setFavouriteGymProfile(any(), any()));
    });

    test('a failed save blocks continuing and says so', () async {
      when(
        () => setup.saveGymProfile(
          any(),
          untitledName: any(named: 'untitledName'),
        ),
      ).thenThrow(Exception('offline'));
      final cubit = build();
      await cubit.continuePressed();
      expect(cubit.state.status, GymProfileEditorStatus.continueFailure);
      verifyNever(() => setup.setFavouriteGymProfile(any(), any()));
      cubit.failureShown();
      expect(cubit.state.status, GymProfileEditorStatus.editing);
    });

    test(
      'a failed favourite is logged and passed over, as Swift does',
      () async {
        when(() => setup.setFavouriteGymProfile(any(), any()))
            .thenThrow(Exception('offline'));
        final cubit = build();
        await cubit.continuePressed();
        expect(cubit.state.status, GymProfileEditorStatus.continued);
        expect(
          analytics.last('GymProfileView_FavouriteGymProfile_Fail').parameters,
          isNull,
        );
      },
    );
  });

  group('the list', () {
    test('appearing is tracked as a screen view', () {
      build();
      expect(analytics.names, ['GymProfileView_OnAppear']);
    });

    test('the filter and the query narrow what is shown', () {
      final cubit = build()..queryChanged('dumbbell');
      expect(
        [
          for (final item in cubit.state.visible(GymEquipmentList.freeWeights))
            item.id,
        ],
        ['dumbbells'],
      );
      cubit
        ..queryChanged('treadmill')
        ..filterChanged(GymEquipmentFilter.selected);
      expect(cubit.state.hidesEverything, isTrue);
      expect(cubit.state.hasUnsavedChanges, isFalse);
    });

    test('a switch changes its own item and waits to be saved', () {
      final cubit = build()
        ..setActive(GymEquipmentList.freeWeights, 'dumbbells', isActive: false);
      expect(
        GymEditorRules.item(
          cubit.state.gym,
          GymEquipmentList.freeWeights,
          'dumbbells',
        )!.isActive,
        isFalse,
      );
      expect(cubit.state.hasUnsavedChanges, isTrue);
    });
  });

  group('machines', () {
    setUp(() => ids = 0);

    test('duplicate adds a copy beside the original and opens nothing', () {
      final cubit = build()
        ..duplicateMachine(GymEquipmentList.cableMachines, latPulldown);
      final machines = cubit.state.gym.cableMachines;
      final index = machines.indexWhere((m) => m.id == latPulldown);
      expect(machines, hasLength(gym.cableMachines.length + 1));
      expect(machines[index + 1].typeId, latPulldown);
      expect(machines[index + 1].name, 'Cable Lat Pulldown Machine 2');
      expect(cubit.state.hasUnsavedChanges, isTrue);
    });

    test('a machine added as a catalogue type is switched on', () {
      final cubit = build();
      final id = cubit.addMachine(
        GymEquipmentList.cableMachines,
        name: 'Hammer Pulldown',
        worksAs: latPulldown,
      );
      final machine = cubit.state.gym.cableMachines.last;
      expect(machine.id, id);
      expect(machine.name, 'Hammer Pulldown');
      expect(machine.typeId, latPulldown);
      expect(machine.isActive, isTrue);
    });

    test("a machine of the user's own is deleted; a catalogue one stays", () {
      final cubit = build()
        ..duplicateMachine(GymEquipmentList.cableMachines, latPulldown);
      final copy = cubit.state.gym.cableMachines.firstWhere(
        (m) => GymEditorRules.isCustom(GymEquipmentList.cableMachines, m),
      );
      cubit
        ..deleteMachine(GymEquipmentList.cableMachines, copy.id)
        ..deleteMachine(GymEquipmentList.cableMachines, latPulldown);
      final ids = [for (final m in cubit.state.gym.cableMachines) m.id];
      expect(ids, isNot(contains(copy.id)));
      expect(ids, contains(latPulldown));
    });
  });
}
