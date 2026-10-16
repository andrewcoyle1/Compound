import 'package:compound/l10n/l10n.dart';
import 'package:compound/notifications/notifications.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:compound_models/compound_models.dart';
import 'package:device_store/device_store.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/library_fixtures.dart';
import '../../onboarding/cubit/helpers.dart';

/// A library whose gym saves are refused.
class _RefusingLibrary extends InMemoryTrainingLibraryRepository {
  new({super.gymProfiles, super.workoutSettings});

  @override
  Future<void> saveGymProfile(GymProfileModel profile) =>
      Future.error(Exception('denied'));
}

const String uid = sampleUserId;

/// The tracker's loading and equipment: the plate calculator's setup and
/// save (Swift `SetTrackerRowPlateCalculatorTests`), bands and ± on the
/// keypad (`SetKeyboardPresenterTests`), and the equipment sheet's choices
/// reaching the exercise.
void main() {
  final now = DateTime(2026, 10, 15, 18);
  final gym = sampleGymProfiles.single;
  late InMemoryTrainingLibraryRepository library;
  late RecordingAnalytics analytics;
  late ActiveWorkoutCubit cubit;
  var ids = 0;

  const bandsRef = EquipmentRef(
    kind: EquipmentKind.bands,
    equipmentId: 'long_elastic_bands',
  );
  const barRef = EquipmentRef(
    kind: EquipmentKind.loadableBar,
    equipmentId: 'barbell',
  );
  ExerciseModel own(
    String id, {
    List<EquipmentRef> resistance = const [],
    bool assisted = false,
  }) {
    final exercise = fixtureLibraryExercise(
      id,
      variations: [
        EquipmentVariation(id: '$id-v', resistanceEquipment: resistance),
      ],
    );
    return ExerciseModel.fromFirestore({
      ...exercise.toFirestore(),
      'author_id': uid,
      if (assisted) 'trackable_metrics': ['weightPerSideAssistance', 'reps'],
    });
  }

  final bandedBench = own('banded-bench', resistance: [barRef, bandsRef]);
  final bandWalk = own('band-walk', resistance: [bandsRef]);
  final assistedDip = own('assisted-dip', assisted: true);

  ActiveWorkoutCubit build({DeviceStore? device}) => ActiveWorkoutCubit(
    sessions: InMemoryWorkoutSessionRepository(sessions: const []),
    users: InMemoryUserRepository(users: {uid: sampleUser(now: now)}),
    library: library,
    analytics: analytics.repository,
    store: InMemoryActiveSessionStore(),
    device: device,
    notifications: FakeNotificationsRepository(),
    copy: AppNotificationCopy(() => lookupAppLocalizations(const Locale('en'))),
    clock: () => now,
    newId: () => 'ID-${++ids}',
    wait: (_) async {},
  );

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  InMemoryTrainingLibraryRepository repository() =>
      InMemoryTrainingLibraryRepository(
        gymProfiles: [gym],
        exercises: [bandedBench, bandWalk, assistedDip],
        workoutSettings: const [
          WorkoutSettings(authorId: uid, addSmartWarmUps: false),
        ],
      );

  setUp(() {
    ids = 0;
    analytics = RecordingAnalytics();
    library = repository();
    cubit = build();
  });

  tearDown(() => cubit.close());

  /// The bench press from My Upper Body, with its first set's weight open.
  Future<String> benchWeightOpen() async {
    await cubit.userChanged(uid);
    await settle();
    await cubit.start(
      template: sampleUserWorkoutTemplates.first,
      eventPrefix: 'x',
    );
    final setId = (cubit.state.primaryAction! as r.LogSetAction).setId;
    cubit.openKeypad(setId, SetField.weight);
    return setId;
  }

  /// [exercise] alone in an empty workout, its first set's weight open.
  Future<String> weightOpen(ExerciseModel exercise) async {
    await cubit.userChanged(uid);
    await settle();
    await cubit.start(eventPrefix: 'x');
    cubit.addExercises([exercise]);
    final setId = cubit.state.session!.exercises.single.sets.first.id;
    cubit.openKeypad(setId, SetField.weight);
    return setId;
  }

  group('the plate calculator', () {
    test('opens on the bar of the workout gym', () async {
      await benchWeightOpen();
      cubit
        ..keypadKey('7')
        ..keypadKey('0');
      final setup = cubit.state.plateCalculatorSetup!;
      expect(setup.gym.id, gym.id);
      expect(setup.equipment.equipmentId, 'barbell');
      expect(setup.unit, ExerciseWeightUnit.kilograms);
      expect(setup.total, 70);
      expect(setup.machineBase, 0);
      expect(cubit.state.card.first.weightStep.baseWeight, 20);

      cubit.plateCalculatorOpened();
      expect(analytics.names, contains('SetTrackerRow_PlateCalculator_Opened'));
    });

    test('a bar chosen there is stepped on and saved', () async {
      final setId = await benchWeightOpen();
      final setup = cubit.state.plateCalculatorSetup!;
      expect(setup.total, isNull);
      final fifteen = GymEditorRules.barChoices(
        setup.gym,
        'barbell',
      ).firstWhere((bar) => bar.baseWeight == 15);

      await cubit.saveGymLoading(
        GymEditorRules.choosingBar(setup.gym, fifteen.id, typeId: 'barbell'),
      );

      expect(cubit.state.card.first.weightStep.baseWeight, 15);
      expect(cubit.state.set(setId)!.weightKg, isNull);
      expect(cubit.state.effect, isA<SavedEffect>());
      final saved = await library.watchGymProfiles(uid).first;
      expect(
        GymEditorRules.loadedBar(saved.single, 'barbell')!.chosenBaseWeightId,
        fifteen.id,
      );
    });

    test('only loading goes onto the gym as it now is', () async {
      await benchWeightOpen();
      final opened = cubit.state.plateCalculatorSetup!.gym;
      // Renamed elsewhere while the calculator was open.
      final renamed = GymEditorRules.renamed(gym, 'Renamed meanwhile');
      await library.saveGymProfile(renamed);
      await settle();

      await cubit.saveGymLoading(
        GymEditorRules.settingPlate(
          opened,
          25,
          ExerciseWeightUnit.kilograms,
          isOn: false,
        ),
      );

      final saved = (await library.watchGymProfiles(uid).first).single;
      expect(saved.name, 'Renamed meanwhile');
      expect(
        GymEditorRules.plateChoices(saved, ExerciseWeightUnit.kilograms).first,
        (weight: 25.0, isOn: false),
      );
    });

    test('a refused save says so', () async {
      library = _RefusingLibrary(
        gymProfiles: [gym],
        workoutSettings: const [WorkoutSettings(authorId: uid)],
      );
      await cubit.close();
      cubit = build();
      await benchWeightOpen();
      await cubit.saveGymLoading(cubit.state.plateCalculatorSetup!.gym);
      expect(cubit.state.effect, isA<GymSaveFailedEffect>());
    });

    test('there is none off a bar, or without a gym', () async {
      await weightOpen(bandWalk);
      expect(cubit.state.plateCalculatorSetup, isNull);
      cubit.closeKeypad();
      expect(cubit.state.plateCalculatorSetup, isNull);

      library = InMemoryTrainingLibraryRepository();
      await cubit.close();
      cubit = build();
      await benchWeightOpen();
      expect(cubit.state.gym, isNull);
      expect(cubit.state.plateCalculatorSetup, isNull);
    });

    test('a weight from the loading bar is set in the display unit', () async {
      final setId = await benchWeightOpen();
      cubit.keypadWeight(67.5);
      expect(cubit.state.set(setId)!.weightKg, 67.5);
      expect(cubit.state.keypad!.text, '67.5');
      expect(cubit.state.effect, isA<SelectionEffect>());
    });

    test('the plates key shows and hides the loading bar', () async {
      await benchWeightOpen();
      expect(cubit.state.showsPlates, isTrue);
      cubit.togglePlates();
      expect(cubit.state.showsPlates, isFalse);
      cubit.keypadKey('5');
      expect(cubit.state.showsPlates, isFalse);
    });

    test('the plates switch is kept on the device', () async {
      final device = InMemoryDeviceStore();
      await cubit.close();
      cubit = build(device: device);
      await benchWeightOpen();
      cubit.togglePlates();
      expect(device.getBool(ActiveWorkoutCubit.showsPlatesKey), isFalse);
      await cubit.close();
      cubit = build(device: device);
      await benchWeightOpen();
      expect(cubit.state.showsPlates, isFalse);
    });
  });

  group('bands', () {
    test('two bands are saved on the set, the weight untouched', () async {
      final setId = await weightOpen(bandedBench);
      cubit
        ..keypadKey('6')
        ..keypadKey('0');
      final step = cubit.state.card.single.weightStep;
      final [first, second, ...] = step.bands;
      cubit
        ..keypadBand(second)
        ..keypadBand(first);
      expect(cubit.state.set(setId)!.bands, [second, first]);
      expect(cubit.state.set(setId)!.weightKg, 60);
      expect(cubit.state.effect, isA<SelectionEffect>());

      // On a bar with bands, ± steps the bar and leaves the bands.
      cubit.keypadStep(up: true);
      expect(cubit.state.set(setId)!.weightKg, 62.5);
      expect(cubit.state.set(setId)!.bands, [second, first]);
    });

    test('deselecting every band leaves no bands', () async {
      final setId = await weightOpen(bandedBench);
      final band = cubit.state.card.single.weightStep.bands.first;
      cubit
        ..keypadBand(band)
        ..keypadBand(band);
      expect(cubit.state.set(setId)!.bands, isNull);
    });

    test('± on bands alone chooses one band at a time', () async {
      final setId = await weightOpen(bandWalk);
      final bands = cubit.state.card.single.weightStep.bands;
      expect(cubit.state.card.single.weightStep.kind, isA<r.StepBands>());
      cubit.keypadStep(up: true);
      expect(cubit.state.set(setId)!.bands, [bands[0]]);
      cubit.keypadBand(bands[1]);
      expect(cubit.state.set(setId)!.bands, [bands[0], bands[1]]);
      cubit.keypadStep(up: true);
      expect(cubit.state.set(setId)!.bands, [bands[2]]);
      expect(cubit.state.set(setId)!.weightKg, isNull);
      cubit
        ..keypadBand(bands[2])
        ..keypadStep(up: false);
      expect(cubit.state.set(setId)!.bands, [bands.last]);
    });
  });

  test('± types assistance on an assisted exercise', () async {
    final setId = await weightOpen(assistedDip);
    expect(cubit.state.keypad!.showsSignKey, isTrue);
    cubit
      ..keypadSign()
      ..keypadKey('3')
      ..keypadKey('0');
    expect(cubit.state.set(setId)!.weightKg, -30);
    cubit.keypadSign();
    expect(cubit.state.set(setId)!.weightKg, 30);
  });

  group('the equipment sheet', () {
    test('opens on the exercise, its library and gyms', () async {
      await benchWeightOpen();
      final bench = cubit.state.session!.exercises.first;
      final setup = cubit.state.equipmentSetup(bench.id)!;
      expect(setup.exercise, bench);
      expect(setup.gym, gym);
      expect(setup.gyms, [gym]);
      expect(setup.library, isNotEmpty);
      expect(cubit.state.equipmentSetup('missing'), isNull);
      cubit.equipmentOpened();
      expect(analytics.names, contains('SetTracker_Equipment_Opened'));
    });

    test('another variation is chosen for the exercise', () async {
      await benchWeightOpen();
      final bench = cubit.state.session!.exercises.first;
      final other = bench.equipmentVariations.last.id;
      cubit.chooseVariation(bench.id, other);
      expect(cubit.state.exercise(bench.id)!.chosenVariationId, other);
      expect(cubit.state.effect, isA<SelectionEffect>());
    });

    test('an edited gym refits the exercise at once', () async {
      final setId = await benchWeightOpen();
      cubit
        ..keypadKey('6')
        ..keypadKey('1')
        ..closeKeypad();
      final bench = cubit.state.session!.exercises.first;
      // Every plate but the 25s off: 61 kg is now 70.
      var edited = gym;
      for (final weight in [1.25, 2.5, 5.0, 10.0, 15.0, 20.0]) {
        edited = GymEditorRules.settingPlate(
          edited,
          weight,
          ExerciseWeightUnit.kilograms,
          isOn: false,
        );
      }
      cubit.gymEdited(bench.id, edited);
      expect(cubit.state.gym, edited);
      expect(cubit.state.set(setId)!.weightKg, 70);
    });
  });

  test('nothing happens before a workout', () async {
    await cubit.userChanged(uid);
    cubit
      ..keypadSign()
      ..keypadBand('Red')
      ..keypadWeight(60)
      ..chooseVariation('e', 'v')
      ..gymEdited('e', gym);
    await cubit.saveGymLoading(gym);
    expect(cubit.state.isActive, isFalse);
  });
}
