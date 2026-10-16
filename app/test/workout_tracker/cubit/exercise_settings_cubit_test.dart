import 'package:bloc_test/bloc_test.dart';
import 'package:compound/workout_tracker/cubit/exercise_settings_cubit.dart';
import 'package:compound/workout_tracker/cubit/swap_exercise_picker_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart';

import '../../helpers/library_fixtures.dart';
import '../../onboarding/cubit/helpers.dart';

const uid = 'u1';

/// Refuses every write, as a refused save would.
class _FailingLibrary extends InMemoryTrainingLibraryRepository {
  new({super.exerciseSettings});

  @override
  Future<void> saveExerciseSettings(String uid, ExerciseSettingsModel s) =>
      Future.error(StateError('refused'));

  @override
  Future<void> clearExerciseRestOverride(String uid, String id) =>
      Future.error(StateError('refused'));
}

void main() {
  final row = ExerciseModel.fromFirestore({
    ...fixtureLibraryExercise('row').toFirestore(),
    'trackable_metrics': ['weight', 'repsPerSide'],
  });
  final bench = fixtureLibraryExercise('bench');

  late RecordingAnalytics analytics;
  late UnitPreferenceStore units;

  setUp(() {
    analytics = RecordingAnalytics();
    units = UnitPreferenceStore();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  ExerciseSettingsCubit make(
    TrainingLibraryRepository library, {
    ExerciseModel? exercise,
    UserModel? user,
  }) => ExerciseSettingsCubit(
    exercise: exercise ?? row,
    uid: uid,
    user: user,
    library: library,
    units: units,
    analytics: analytics.repository,
  );

  group('ExerciseSettingsCubit', () {
    test('reads the units, note, rest and side rest', () async {
      final cubit = make(
        InMemoryTrainingLibraryRepository(
          exerciseSettings: [
            ExerciseSettingsModel(
              id: row.id,
              authorId: uid,
              note: 'Brace\nthen pull',
              restDurationOverride: 120,
            ),
          ],
          workoutSettings: const [
            WorkoutSettings(
              authorId: uid,
              restBetweenSideSets: true,
              sideSetRestScaling: 0.25,
              defaultRestDurationSeconds: 60,
            ),
          ],
        ),
        user: const UserModel(
          userId: uid,
          submittedWeightUnitPreference: WeightUnitPreference.pounds,
        ),
      );
      await settle();
      final state = cubit.state;
      expect(state.units.weightUnit, ExerciseWeightUnit.pounds);
      expect(state.noteSummary, 'Brace');
      expect(state.restOverride, 120);
      expect(state.defaultRest, 60);
      expect(state.isPerSide, isTrue);
      expect(state.sideSetRestPercent, 25);
      cubit
        ..appeared()
        ..disappeared();
      expect(analytics.names, [
        'ExerciseSettingsView_Appear',
        'ExerciseSettingsView_Disappear',
      ]);
      await cubit.close();
    });

    test('with nothing stored: no note, the default rest, side rest off', () {
      final cubit = make(InMemoryTrainingLibraryRepository(), exercise: bench);
      expect(cubit.state.noteSummary, isNull);
      expect(cubit.state.defaultRest, 90);
      expect(cubit.state.isPerSide, isFalse);
      expect(cubit.state.sideSetRestPercent, isNull);
      return cubit.close();
    });

    test('units are kept on the device for this exercise', () async {
      final cubit = make(InMemoryTrainingLibraryRepository())
        ..weightUnitChanged(ExerciseWeightUnit.pounds)
        ..distanceUnitChanged(DistanceUnit.miles);
      expect(cubit.state.units.weightUnit, ExerciseWeightUnit.pounds);
      expect(cubit.state.units.distanceUnit, DistanceUnit.miles);
      expect(units.of(uid, row.id).weightUnitIsChosen, isTrue);
      expect(units.of(uid, row.id).distanceUnit, DistanceUnit.miles);
      expect(units.of(uid, bench.id).weightUnitIsChosen, isFalse);
      await cubit.close();
    });

    test('a rest is saved, and cleared by deleting it', () async {
      final library = InMemoryTrainingLibraryRepository();
      final cubit = make(library);
      await cubit.restChanged(150);
      await settle();
      var stored = await library.watchExerciseSettings(uid).first;
      expect(stored.single.restDurationOverride, 150);
      expect(cubit.state.restOverride, 150);

      await cubit.restChanged(0);
      await settle();
      stored = await library.watchExerciseSettings(uid).first;
      expect(stored.single.restDurationOverride, isNull);
      expect(cubit.state.restOverride, isNull);

      // Nothing to clear: nothing is written.
      await cubit.restChanged(0);
      expect(analytics.names, isNot(contains(contains('_Fail'))));
      await cubit.close();
    });

    test('a note is saved trimmed; a blank one as ""', () async {
      final library = InMemoryTrainingLibraryRepository();
      final cubit = make(library);
      await cubit.noteChanged('  Slow  ');
      await settle();
      var stored = await library.watchExerciseSettings(uid).first;
      expect(stored.single.note, 'Slow');
      // Unchanged: nothing written.
      await cubit.noteChanged('Slow ');
      await cubit.noteChanged('  ');
      await settle();
      stored = await library.watchExerciseSettings(uid).first;
      expect(stored.single.note, '');
      await cubit.close();
    });

    test('a refused save is reported as a warning', () async {
      final cubit = make(
        _FailingLibrary(
          exerciseSettings: [
            ExerciseSettingsModel(
              id: row.id,
              authorId: uid,
              restDurationOverride: 90,
            ),
          ],
        ),
      );
      await settle();
      await cubit.restChanged(60);
      await cubit.restChanged(0);
      await cubit.noteChanged('x');
      expect(analytics.names, [
        'ExerciseSettingsView_SaveRestOverride_Fail',
        'ExerciseSettingsView_SaveRestOverride_Fail',
        'ExerciseSettingsView_SaveNote_Fail',
      ]);
      await cubit.close();
    });
  });

  // SwapExercisePickerPresenter: the plan's alternatives first, both lists
  // searched by name.
  group('SwapExercisePickerCubit', () {
    final squat = fixtureLibraryExercise('squat', name: 'Back Squat');
    final front = fixtureLibraryExercise('front', name: 'Front Squat');
    final press = fixtureLibraryExercise('press', name: 'Leg Press');

    SwapExercisePickerCubit picker() => SwapExercisePickerCubit(
      library: [squat, front, press],
      alternativeIds: const ['press', 'gone', 'front'],
      analytics: analytics.repository,
    );

    test('lists the alternatives the library holds, in the plan order', () {
      final cubit = picker();
      expect(cubit.state.plannedAlternatives, [press, front]);
      expect(cubit.state.exercises, [squat, front, press]);
      return cubit.close();
    });

    blocTest<SwapExercisePickerCubit, SwapExercisePickerState>(
      'search narrows both lists, ignoring case',
      build: picker,
      act: (cubit) => cubit.searchChanged('SQUAT'),
      verify: (cubit) {
        expect(cubit.state.plannedAlternatives, [front]);
        expect(cubit.state.exercises, [squat, front]);
      },
    );

    test('logs the appearance and whether a pick was planned', () async {
      final cubit = picker()
        ..appeared()
        ..selected(press)
        ..selected(squat);
      expect(analytics.names, [
        'SwapExercisePicker_Appear',
        'SwapExercisePicker_Exercise_Selected',
        'SwapExercisePicker_Exercise_Selected',
      ]);
      expect(analytics.events.first.parameters, {'planned_alternatives': 3});
      expect(analytics.events[1].parameters, {'planned_alternative': true});
      expect(analytics.events[2].parameters, {'planned_alternative': false});
      await cubit.close();
    });
  });
}
