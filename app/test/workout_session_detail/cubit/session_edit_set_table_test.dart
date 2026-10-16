import 'package:compound/workout_session_detail/cubit/session_edit_cubit.dart';
import 'package:compound/workout_tracker/logic/set_keypad.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/analytics_recorder.dart';
import '../../helpers/library_fixtures.dart';

const _uid = 'author-1';

/// A library whose writes can be refused.
class _Library extends InMemoryTrainingLibraryRepository {
  new({super.exercises, super.gymProfiles, super.exerciseSettings});

  bool refuse = false;

  @override
  Future<void> saveGymProfile(GymProfileModel profile) => refuse
      ? Future.error(Exception('denied'))
      : super.saveGymProfile(profile);

  @override
  Future<void> saveExerciseSettings(
    String uid,
    ExerciseSettingsModel settings,
  ) => refuse
      ? Future.error(Exception('denied'))
      : super.saveExerciseSettings(uid, settings);
}

/// A finished workout's editor beyond #162's: the set table it shares with
/// the tracker (keypad, units, stopwatch, plate calculator), the exercise
/// chips (equipment, targets, swap, superset) and the exercise note. Ported
/// from Swift's `SetTrackerPresenterTests` (swap, supersets, units,
/// navigation) and `WorkoutSessionDetailPresenterTests` (superset group,
/// replacing an exercise, unit preferences).
void main() {
  final start = DateTime(2026, 3, 9, 7);
  final today = DateTime(2026, 3, 10, 18);
  final gym = GymProfileModel.fromFirestore({
    ...sampleGymProfiles.single.toFirestore(),
    'author_id': _uid,
  });
  const barRef = EquipmentRef(
    kind: EquipmentKind.loadableBar,
    equipmentId: 'barbell',
  );

  ExerciseModel own(String id, {List<TrackableExerciseMetric>? metrics}) =>
      ExerciseModel.fromFirestore({
        ...fixtureLibraryExercise(
          id,
          name: 'Lift $id',
          variations: [
            EquipmentVariation(
              id: '$id-v1',
              resistanceEquipment: const [barRef],
            ),
            const EquipmentVariation(id: 'other'),
          ],
        ).toFirestore(),
        'author_id': _uid,
        if (metrics != null)
          'trackable_metrics': [for (final m in metrics) m.value],
      });

  final bench = own('bench');
  final row = own('row');
  final plank = own('plank', metrics: const [TrackableExerciseMetric.duration]);

  WorkoutSetModel set(
    String id, {
    int index = 1,
    int? reps = 8,
    double? weightKg = 80,
    bool logged = true,
    bool isWarmup = false,
    double? distance,
  }) => WorkoutSetModel(
    id: id,
    authorId: _uid,
    index: index,
    reps: reps,
    weightKg: weightKg,
    distanceMeters: distance,
    isWarmup: isWarmup,
    dateCreated: start,
    completedAt: logged ? start : null,
  );

  WorkoutExerciseModel exercise(
    String id,
    int index,
    List<WorkoutSetModel> sets, {
    String templateId = 'bench',
    String? group,
    TrackingMode mode = TrackingMode.weightReps,
  }) => WorkoutExerciseModel(
    id: id,
    authorId: _uid,
    templateId: templateId,
    name: 'Exercise $id',
    trackingMode: mode,
    index: index,
    sets: sets,
    supersetGroupId: group,
    equipmentVariations: bench.equipmentVariations,
    chosenVariationId: 'bench-v1',
  );

  WorkoutSessionModel session(List<WorkoutExerciseModel> exercises) =>
      WorkoutSessionModel(
        id: 'session-1',
        authorId: _uid,
        name: 'Push Day',
        dateCreated: start,
        dateModified: start,
        endedAt: start.add(const Duration(hours: 1)),
        gymProfileId: gym.id,
        exercises: exercises,
      );

  late InMemoryWorkoutSessionRepository sessions;
  late _Library library;
  late UnitPreferenceStore units;
  late AnalyticsRecorder analytics;

  setUp(() {
    sessions = InMemoryWorkoutSessionRepository(sessions: const []);
    library = _Library(
      exercises: [bench, row, plank],
      gymProfiles: [gym],
      exerciseSettings: const [
        ExerciseSettingsModel(id: 'bench', authorId: _uid, note: 'Elbows in'),
      ],
    );
    units = UnitPreferenceStore();
    analytics = AnalyticsRecorder();
  });

  var ids = 0;
  Future<SessionEditCubit> editing(List<WorkoutExerciseModel> exercises) async {
    final opened = session(exercises);
    await sessions.saveSession(_uid, opened);
    final cubit = SessionEditCubit(
      session: opened,
      sessions: sessions,
      users: InMemoryUserRepository(
        users: {_uid: const UserModel(userId: _uid)},
      ),
      analytics: analytics,
      uid: _uid,
      library: library,
      units: units,
      clock: () => today,
      newId: () => 'new-${ids++}',
    );
    addTearDown(cubit.close);
    await cubit.enterEditMode();
    return cubit;
  }

  List<String?> groups(SessionEditCubit cubit) => [
    for (final e in cubit.state.session.exercises) e.supersetGroupId,
  ];

  group('The set table', () {
    test('each exercise with its units, steps and note', () async {
      final cubit = await editing([
        exercise('e1', 1, [set('s1')]),
      ]);
      final member = cubit.state.member('e1')!;
      expect(member.exerciseNote, 'Elbows in');
      expect(member.weightUnit, ExerciseWeightUnit.kilograms);
      expect(member.previous, isNull);
      // The workout's gym: its bar sets the steps.
      expect(member.weightStep.baseWeight, isNotNull);
      expect(cubit.state.gym?.id, gym.id);
      expect(cubit.state.member('missing'), isNull);
    });

    test('leaving edit mode drops it', () async {
      final cubit = await editing([
        exercise('e1', 1, [set('s1')]),
      ]);
      cubit
        ..openKeypad('s1', SetField.reps)
        ..endEditing();
      expect(cubit.state.members, isEmpty);
      expect(cubit.state.keypad, isNull);
    });
  });

  group('Supersets', () {
    test('a superset group is set on the pair only', () async {
      final cubit =
          await editing([
              exercise('e1', 1, [set('s1')]),
              exercise('e2', 2, [set('s2')]),
              exercise('e3', 3, [set('s3')]),
            ])
            ..pairSuperset('e2', 'e3');
      expect(groups(cubit), [null, 'new-0', 'new-0']);

      // A partner already grouped makes a circuit.
      cubit.pairSuperset('e1', 'e3');
      expect(groups(cubit), ['new-0', 'new-0', 'new-0']);
    });

    test('leaving a pair dissolves the group', () async {
      final cubit =
          await editing([
              exercise('e1', 1, [set('s1')], group: 'g'),
              exercise('e2', 2, [set('s2')], group: 'g'),
            ])
            ..leaveSuperset('e1');
      expect(groups(cubit), [null, null]);
    });

    test('leaving a group of three leaves the others grouped', () async {
      final cubit =
          await editing([
              exercise('e1', 1, [set('s1')], group: 'g'),
              exercise('e2', 2, [set('s2')], group: 'g'),
              exercise('e3', 3, [set('s3')], group: 'g'),
            ])
            ..leaveSuperset('e1');
      expect(groups(cubit), [null, 'g', 'g']);
    });

    test('pairing with nothing available changes nothing', () async {
      final cubit =
          await editing([
              exercise('e1', 1, [set('s1')]),
              exercise('e2', 2, [set('s2')], group: 'g'),
            ])
            ..pairSuperset('e1', 'e1')
            ..pairSuperset('e1', 'missing')
            ..pairSuperset('e2', 'e1')
            ..leaveSuperset('e1')
            ..leaveSuperset('missing');
      expect(groups(cubit), [null, 'g']);
      expect(cubit.state.hasUnsavedChanges, isFalse);
    });
  });

  group('Swap', () {
    test('measured the same way, the logged sets stay in place', () async {
      final cubit = await editing([
        exercise('e1', 1, [set('s1'), set('s2', index: 2, logged: false)]),
        exercise('e2', 2, [set('s3')]),
      ]);
      expect(cubit.state.asksBeforeSwapping('e1', row), isFalse);
      cubit
        ..swapOpened()
        ..swapExercise('e1', row, keepLoggedSets: true);
      final swapped = cubit.state.session.exercises.first;
      expect(swapped.id, 'e1');
      expect(swapped.templateId, 'row');
      expect(swapped.name, 'Lift row');
      expect(swapped.sets.first.id, 's1');
      expect(swapped.sets, hasLength(2));
      expect(cubit.state.session.exercises.last.templateId, 'bench');
      expect(analytics.names, contains('SetTracker_Swap_Opened'));
    });

    test('measured differently, it asks before discarding', () async {
      final cubit = await editing([
        exercise('e1', 1, [set('s1')]),
      ]);
      expect(cubit.state.asksBeforeSwapping('e1', plank), isTrue);
      expect(cubit.state.asksBeforeSwapping('missing', plank), isFalse);
      expect(cubit.state.session.exercises.single.templateId, 'bench');

      cubit.swapExercise('e1', plank, keepLoggedSets: false);
      final swapped = cubit.state.session.exercises.single;
      expect(swapped.templateId, 'plank');
      expect(swapped.sets, hasLength(3));
      expect(swapped.sets.every((s) => s.completedAt == null), isTrue);
    });

    test(
      'nothing logged asks nothing; a missing exercise changes nothing',
      () async {
        final cubit = await editing([
          exercise('e1', 1, [set('s1', logged: false)]),
        ]);
        expect(cubit.state.asksBeforeSwapping('e1', plank), isFalse);
        cubit
          ..openKeypad('s1', SetField.reps)
          ..swapExercise('missing', row, keepLoggedSets: true);
        expect(cubit.state.hasUnsavedChanges, isFalse);
        expect(cubit.state.keypad, isNotNull);
        // The keypad on the swapped exercise closes with it.
        cubit.swapExercise('e1', row, keepLoggedSets: true);
        expect(cubit.state.keypad, isNull);
      },
    );
  });

  group('Units', () {
    test('a unit changed after opening is used', () async {
      final cubit = await editing([
        exercise('e1', 1, [set('s1')]),
      ]);
      units.setWeightUnit(_uid, 'bench', ExerciseWeightUnit.pounds);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.member('e1')!.weightUnit, ExerciseWeightUnit.pounds);
    });

    test('display only changes the unit and leaves the weights', () async {
      final cubit =
          await editing([
              exercise('e1', 1, [
                set('s1'),
                set('s2', index: 2, logged: false),
              ]),
            ])
            ..changeWeightUnit('e1', ExerciseWeightUnit.pounds, convert: false);
      final saved = units.of(_uid, 'bench');
      expect(saved.weightUnit, ExerciseWeightUnit.pounds);
      expect(saved.distanceUnit, DistanceUnit.meters);
      final sets = cubit.state.session.exercises.single.sets;
      expect(sets.map((s) => s.weightKg), [80, 80]);
      expect(cubit.state.member('e1')!.weightUnit, ExerciseWeightUnit.pounds);
      expect(analytics.names, contains('SetTracker_Unit_Changed'));
    });

    test('converting rounds the open sets and leaves the logged', () async {
      final cubit =
          await editing([
              exercise('e1', 1, [
                set('s1'),
                set('s2', index: 2, logged: false),
              ]),
            ])
            ..changeWeightUnit('e1', ExerciseWeightUnit.pounds, convert: true);
      final sets = cubit.state.session.exercises.single.sets;
      expect(sets.first.weightKg, 80);
      expect(sets.last.weightKg, isNot(80));
      expect(analytics.names, isNot(contains('SetTracker_Unit_Changed')));
    });

    test('the distance unit keeps the weight unit; convert rounds', () async {
      units.setWeightUnit(_uid, 'bench', ExerciseWeightUnit.pounds);
      final cubit =
          await editing([
              exercise('e1', 1, [
                set('s1', distance: 5432),
                set('s2', index: 2, logged: false, distance: 5432),
              ], mode: TrackingMode.distanceTime),
            ])
            ..changeDistanceUnit('e1', DistanceUnit.miles, convert: true);
      final saved = units.of(_uid, 'bench');
      expect(saved.weightUnit, ExerciseWeightUnit.pounds);
      expect(saved.distanceUnit, DistanceUnit.miles);
      final sets = cubit.state.session.exercises.single.sets;
      expect(sets.first.distanceMeters, 5432);
      expect(sets.last.distanceMeters, isNot(5432));
      expect(cubit.state.member('e1')!.distanceUnit, DistanceUnit.miles);
      cubit
        ..changeDistanceUnit('missing', DistanceUnit.meters, convert: false)
        ..changeWeightUnit(
          'missing',
          ExerciseWeightUnit.kilograms,
          convert: false,
        );
      expect(units.of(_uid, 'bench').distanceUnit, DistanceUnit.miles);
    });
  });

  group('Notes', () {
    test(
      "this workout's note joins the edit; the exercise note is saved",
      () async {
        final cubit = await editing([
          exercise('e1', 1, [set('s1')]),
        ]);
        await cubit.saveExerciseNotes(
          'e1',
          sessionNote: ' Felt heavy ',
          exerciseNote: ' Tuck the elbows ',
        );
        expect(cubit.state.session.exercises.single.notes, 'Felt heavy');
        expect(cubit.state.member('e1')!.exerciseNote, 'Tuck the elbows');
        final stored = await library.watchExerciseSettings(_uid).first;
        expect(stored.single.note, 'Tuck the elbows');
        expect(cubit.state.savedId, 1);
        expect(analytics.names, contains('ExerciseTracker_ExerciseNote_Saved'));
      },
    );

    test(
      'a blank exercise note is written as "", unchanged as nothing',
      () async {
        final cubit = await editing([
          exercise('e1', 1, [set('s1')]),
        ]);
        await cubit.saveExerciseNotes(
          'e1',
          sessionNote: '',
          exerciseNote: 'Elbows in',
        );
        expect(
          analytics.names,
          isNot(contains('ExerciseTracker_ExerciseNote_Saved')),
        );
        expect(cubit.state.hasUnsavedChanges, isFalse);

        await cubit.saveExerciseNotes(
          'e1',
          sessionNote: '',
          exerciseNote: '  ',
        );
        final stored = await library.watchExerciseSettings(_uid).first;
        expect(stored.single.note, '');
        expect(cubit.state.member('e1')!.exerciseNote, isNull);
        await cubit.saveExerciseNotes(
          'missing',
          sessionNote: 'x',
          exerciseNote: 'y',
        );
      },
    );

    test('a refused exercise note says so', () async {
      final cubit = await editing([
        exercise('e1', 1, [set('s1')]),
      ]);
      library.refuse = true;
      await cubit.saveExerciseNotes('e1', sessionNote: '', exerciseNote: 'x');
      expect(cubit.state.notice, SessionEditNotice.exerciseNoteFailed);
      expect(analytics.names, contains('ExerciseTracker_ExerciseNote_Fail'));
    });
  });

  group('Keypad', () {
    test('types into a set and logs it from ✓', () async {
      final cubit = await editing([
        exercise('e1', 1, [set('s1', logged: false)]),
      ]);
      cubit.openKeypad('s1', SetField.weight);
      expect(cubit.state.keypad?.field, SetField.weight);
      cubit
        ..keypadKey('9')
        ..keypadKey('0')
        ..keypadNext();
      expect(cubit.state.keypad?.field, SetField.reps);
      cubit
        ..keypadKey('5')
        ..keypadBackspace()
        ..keypadKey('6')
        ..keypadDone();
      final logged = cubit.state.session.exercises.single.sets.single;
      expect(logged.weightKg, 90);
      expect(logged.reps, 6);
      expect(logged.completedAt, today);
      expect(cubit.state.keypad, isNull);
      expect(
        analytics.parameters('SetTrackerRow_SetCompleted')?['source'],
        'keypad',
      );
    });

    test('a set that cannot be logged keeps the keypad open', () async {
      final cubit = await editing([
        exercise('e1', 1, [set('s1', logged: false, reps: null)]),
      ]);
      cubit
        ..openKeypad('s1', SetField.reps)
        ..keypadDone();
      expect(cubit.state.notice, SessionEditNotice.logProblem);
      expect(cubit.state.keypad, isNotNull);
      cubit.closeKeypad();
      expect(cubit.state.keypad, isNull);
      // Closed already: nothing more to close.
      cubit.closeKeypad();
    });

    test('steps, chips and bands', () async {
      final cubit = await editing([
        exercise('e1', 1, [set('s1')]),
      ]);
      cubit
        ..openKeypad('s1', SetField.weight)
        ..keypadStep(up: true);
      final stepped = cubit.state.session.exercises.single.sets.single;
      expect(stepped.weightKg, greaterThan(80));
      // A logged set only closes on ✓.
      cubit
        ..keypadStep(up: false)
        ..keypadWeight(100)
        ..keypadBand('Red')
        ..keypadReps(12)
        ..keypadRir(2);
      var edited = cubit.state.session.exercises.single.sets.single;
      expect(edited.weightKg, 100);
      expect(edited.bands, ['Red']);
      expect(edited.reps, 12);
      expect(edited.rpe, r.EffortScale.rpeFromRir(2));
      cubit
        ..keypadBand('Red')
        ..keypadRir(2)
        ..keypadSign();
      edited = cubit.state.session.exercises.single.sets.single;
      expect(edited.bands, isNull);
      expect(edited.rpe, isNull);
      expect(edited.completedAt, start);
      cubit.keypadDone();
      expect(cubit.state.keypad, isNull);
      expect(cubit.state.hasUnsavedChanges, isTrue);
    });

    test('nothing happens with no keypad open', () async {
      final cubit = await editing([
        exercise('e1', 1, [set('s1')]),
      ]);
      final before = cubit.state;
      cubit
        ..openKeypad('missing', SetField.reps)
        ..keypadKey('1')
        ..keypadBackspace()
        ..keypadStep(up: true)
        ..keypadSign()
        ..keypadWeight(10)
        ..keypadBand('Red')
        ..keypadReps(1)
        ..keypadRir(1)
        ..keypadNext()
        ..keypadDone()
        ..stopwatchStopped('missing', 30);
      expect(cubit.state, before);
    });

    test('the plates key and the stopwatch', () async {
      final cubit =
          await editing([
              exercise('e1', 1, [set('s1', logged: false)]),
            ])
            ..togglePlates();
      expect(cubit.state.showsPlates, isFalse);
      cubit.stopwatchStopped('s1', 45);
      final timed = cubit.state.session.exercises.single.sets.single;
      expect(timed.durationSec, 45);
      expect(timed.completedAt, isNull);
    });
  });

  group('Plate calculator', () {
    test('opens on the set and saves the gym', () async {
      final cubit = await editing([
        exercise('e1', 1, [set('s1')]),
      ]);
      expect(cubit.state.plateCalculatorSetup, isNull);
      cubit
        ..openKeypad('s1', SetField.weight)
        ..plateCalculatorOpened();
      final setup = cubit.state.plateCalculatorSetup!;
      expect(setup.total, 80);
      await cubit.saveGymLoading(setup.gym);
      expect(cubit.state.savedId, 1);
      expect(analytics.names, contains('SetTrackerRow_PlateCalculator_Opened'));

      library.refuse = true;
      await cubit.saveGymLoading(setup.gym);
      expect(cubit.state.notice, SessionEditNotice.gymSaveFailed);
    });
  });

  group('Equipment, Targets and Exercise Settings', () {
    test('only open for an exercise the library knows', () async {
      final cubit = await editing([
        exercise('e1', 1, [set('s1')]),
        exercise('e2', 2, [set('s2')], templateId: 'gone'),
      ]);
      expect(cubit.state.libraryModel('e1')?.id, 'bench');
      expect(cubit.state.libraryModel('e2'), isNull);
      expect(cubit.state.libraryModel('missing'), isNull);
      expect(cubit.state.equipmentSetup('e1')?.gym?.id, gym.id);
      expect(cubit.state.equipmentSetup('missing'), isNull);
      cubit
        ..equipmentOpened()
        ..targetsOpened()
        ..exerciseSettingsOpened();
      expect(analytics.names, [
        'SetTracker_Equipment_Opened',
        'SetTracker_Targets_Opened',
        'SetTracker_ExerciseSettings_Opened',
      ]);
    });

    test('a variation chosen, the gym edited, the targets set', () async {
      final cubit =
          await editing([
              exercise('e1', 1, [set('s1')]),
            ])
            ..chooseVariation('e1', 'other');
      expect(cubit.state.session.exercises.single.chosenVariationId, 'other');
      final renamed = GymProfileModel.fromFirestore({
        ...gym.toFirestore(),
        'name': 'Renamed',
      });
      cubit.gymEdited('e1', renamed);
      expect(cubit.state.gym?.name, 'Renamed');
      cubit.setTargets('e1', const [
        SetTarget(id: 't', setNumber: 1, minReps: 3, maxReps: 5),
      ]);
      expect(cubit.state.session.exercises.single.setTargets.single.minReps, 3);
    });
  });
}
