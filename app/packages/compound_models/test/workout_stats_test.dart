import 'package:compound_models/compound_models.dart';
import 'package:test/test.dart';

/// Mirrors the Swift app's `WorkoutSessionRowStatsTests`,
/// `SessionVolumeUnitTests` and the pairing rules in `WorkoutSetPairing.swift`.
void main() {
  final start = DateTime.utc(2026, 3, 2, 18);

  WorkoutSetModel set(
    String id, {
    int? reps,
    double? kilograms,
    bool warmup = false,
    bool completed = true,
    String? side,
    String? parent,
    int? loadCount,
    double? machineBaseKg,
    String? unit,
  }) => WorkoutSetModel(
    id: id,
    authorId: 'me',
    index: 1,
    isWarmup: warmup,
    dateCreated: start,
    completedAt: completed ? start : null,
    reps: reps,
    weightKg: kilograms,
    sideRawValue: side,
    parentSetId: parent,
    loadCount: loadCount,
    machineBaseKg: machineBaseKg,
    weightUnitRawValue: unit,
  );

  WorkoutExerciseModel exercise(
    List<WorkoutSetModel> sets, {
    ExerciseWeightUnit? unit,
    String id = 'e',
  }) => WorkoutExerciseModel(
    id: id,
    authorId: 'me',
    templateId: 't-$id',
    name: 'Lift',
    trackingMode: TrackingMode.weightReps,
    index: 1,
    sets: sets,
    weightUnit: unit,
  );

  WorkoutSessionModel session(
    List<WorkoutExerciseModel> exercises, {
    int? minutes = 65,
    double? pausedSeconds,
  }) => WorkoutSessionModel(
    id: 'session',
    authorId: 'me',
    name: 'Push',
    dateCreated: start,
    dateModified: start,
    endedAt: minutes == null ? null : start.add(Duration(minutes: minutes)),
    pausedSeconds: pausedSeconds,
    exercises: exercises,
  );

  group('WorkoutSetStats', () {
    test('volume is weight × reps, doubled for both sides and two loads', () {
      expect(set('a', reps: 10, kilograms: 50).volumeKg, 500);
      expect(set('a', reps: 10, kilograms: 20, side: 'both').volumeKg, 400);
      expect(set('a', reps: 10, kilograms: 20, loadCount: 2).volumeKg, 400);
      expect(set('a', reps: 10, kilograms: 20, loadCount: 0).volumeKg, 200);
    });

    test('volume leaves out a machine base, assistance and missing values', () {
      expect(
        set('a', reps: 10, kilograms: 60, machineBaseKg: 20).volumeKg,
        400,
      );
      expect(set('a', reps: 10, kilograms: -20).volumeKg, isNull);
      expect(set('a', kilograms: 20).volumeKg, isNull);
      expect(set('a', reps: 10).volumeKg, isNull);
      expect(set('a').loadKg, isNull);
    });

    test('a set with a parent is a sub-set', () {
      expect(set('a', parent: 'p').isSubSet, isTrue);
      expect(set('a').isSubSet, isFalse);
    });
  });

  group('WorkoutSetListStats', () {
    test('a left/right pair is one set and a sub-set adds nothing', () {
      expect(
        [
          set('1l', side: 'left'),
          set('1r', side: 'right'),
          set('2l', side: 'left'),
          set('2r', side: 'right'),
          set('drop', parent: '2l'),
          set('3'),
        ].pairedSetCount,
        3,
      );
      // A right with no left before it still counts.
      expect([set('r', side: 'right')].pairedSetCount, 1);
    });
  });

  group('WorkoutExerciseStats', () {
    test('working and logged sets leave out warm-ups and open sets', () {
      final lift = exercise([
        set('w', warmup: true),
        set('1'),
        set('2', completed: false),
      ]);
      expect(lift.workingSets.map((s) => s.id), ['1', '2']);
      expect(lift.loggedWorkingSets.map((s) => s.id), ['1']);
      expect(lift.loggedSetCount, 1);
    });

    test('a pair shares its number and a drop takes its parent’s', () {
      final sets = [
        set('w', warmup: true),
        set('1l', side: 'left'),
        set('1r', side: 'right'),
        set('2l', side: 'left'),
        set('drop', parent: '2l'),
      ];
      final lift = exercise(sets);
      expect(
        [for (final s in sets.skip(1)) lift.workingSetNumber(s)],
        [1, 1, 2, 2],
      );
    });

    test('shows the exercise’s unit, else a set’s, else kilograms', () {
      expect(
        exercise([
          set('1', unit: 'kilograms'),
        ], unit: ExerciseWeightUnit.pounds).displayWeightUnit,
        ExerciseWeightUnit.pounds,
      );
      expect(
        exercise([set('1'), set('2', unit: 'pounds')]).displayWeightUnit,
        ExerciseWeightUnit.pounds,
      );
      expect(
        exercise([set('1')]).displayWeightUnit,
        ExerciseWeightUnit.kilograms,
      );
    });
  });

  group('WorkoutSessionStats', () {
    test('volume counts logged working sets only', () {
      // testVolumeCountsWorkingSetsOnlyAndSwitchesToTonnes
      final light = session([
        exercise([
          set('1', reps: 10, kilograms: 20, warmup: true),
          set('2', reps: 10, kilograms: 50),
          set('3', reps: 10, kilograms: 50, completed: false),
        ]),
      ]);
      expect(light.loggedVolumeKg, 500);
      expect(light.loggedSetCount, 1);
    });

    test('mixed units sum in kilograms', () {
      // SessionVolumeUnitTests: 100 kg × 10 and 225 lb × 5.
      final mixed = session([
        exercise([set('a', reps: 10, kilograms: 100)], id: 'kg'),
        exercise([set('b', reps: 5, kilograms: 225 / 2.20462)], id: 'lb'),
      ]);
      expect(mixed.loggedVolumeKg, closeTo(1510.29, 0.01));
    });

    test('done exercises are those with a logged set', () {
      final done = exercise([set('1')], id: 'done');
      final skipped = exercise([set('2', completed: false)], id: 'skipped');
      expect(session([done, skipped]).doneExercises, [done]);
    });

    test('active duration leaves out pauses and is absent while running', () {
      // testDurationGoesThroughFormatAndIsAbsentWhileRunning
      expect(session([]).activeDuration, const Duration(minutes: 65));
      expect(
        session([], pausedSeconds: 300).activeDuration,
        const Duration(minutes: 60),
      );
      expect(
        session([], minutes: 1, pausedSeconds: 600).activeDuration,
        Duration.zero,
      );
      expect(session([], minutes: null).activeDuration, isNull);
    });

    test('the author’s unit is the one most logged sets were entered in', () {
      expect(
        session([
          exercise([set('1', unit: 'pounds'), set('2', unit: 'pounds')]),
          exercise([set('3', unit: 'kilograms')], id: 'kg'),
        ]).authorWeightUnit,
        ExerciseWeightUnit.pounds,
      );
      expect(
        session([
          exercise([set('1', unit: 'pounds'), set('2', unit: 'kilograms')]),
        ]).authorWeightUnit,
        ExerciseWeightUnit.kilograms,
      );
      expect(session([]).authorWeightUnit, ExerciseWeightUnit.kilograms);
    });
  });
}
