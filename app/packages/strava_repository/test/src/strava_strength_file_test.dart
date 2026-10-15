// What a workout becomes on Strava: the JSON strength file, the
// description, and the form they are sent in (Swift
// StravaStrengthFileTests). Pure mapping, no repository.
import 'dart:convert';
import 'dart:io';

import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strava_repository/strava_repository.dart';

import '../helpers/fixtures.dart';

int _london(DateTime _) => 0;

StravaStrengthFile _file(
  WorkoutSessionModel workout, [
  List<ExerciseModel> library = const [],
]) => StravaStrengthFile.from(workout, library, utcOffsetAt: _london)!;

void main() {
  group('StravaStrengthFile', () {
    // Elapsed time runs from start to end; active time leaves the pauses
    // out. Both are truncated to whole seconds.
    test('carries the start and both durations', () {
      final file = _file(
        session(
          endedAt: start.add(const Duration(milliseconds: 1805900)),
          pausedSeconds: 100.5,
        ),
      );

      expect(file.startTime, '2023-11-14T22:13:20Z');
      expect(file.utcOffset, 0);
      expect(file.elapsedTime, 1805);
      expect(file.activeTime, 1705);
    });

    test('never has a negative active time', () {
      expect(_file(session(pausedSeconds: 9999)).activeTime, 0);
    });

    test('takes the device offset by default', () {
      final file = StravaStrengthFile.from(session(), const [])!;
      expect(file.utcOffset, start.toLocal().timeZoneOffset.inSeconds);
    });

    test('is nothing for a workout still under way', () {
      expect(StravaStrengthFile.from(session(running: true), const []), isNull);
    });

    // Strava's map counts sets, so only the work done goes: no warm-ups,
    // nothing left unticked, no drops. A bodyweight set's zero weight is
    // left out rather than sent as a 0 kg load.
    test('sends only completed working sets', () {
      final workout = session(
        exercises: [
          exercise(
            sets: [
              row('warm', weightKg: 40, isWarmup: true),
              row('done', reps: 5),
              row('drop', reps: 4, weightKg: 80, parentSetId: 'done'),
              row('bodyweight', reps: 12, weightKg: 0),
              row('skipped', completed: false),
            ],
          ),
        ],
      );

      expect(_file(workout).sets, const [
        StravaStrengthSet(
          exerciseType: 'BARBELL_BENCH_PRESS',
          repetitions: 5,
          weight: 100,
        ),
        StravaStrengthSet(exerciseType: 'BARBELL_BENCH_PRESS', repetitions: 12),
      ]);
    });

    test('sends the load less a machine base kept out of it', () {
      final workout = session(
        exercises: [
          exercise(sets: [row('a', weightKg: 60, machineBaseKg: 20)]),
        ],
      );

      expect(_file(workout).sets.single.weight, 40);
    });

    test('sends a timed set with its duration', () {
      final workout = session(
        exercises: [
          exercise(
            templateId: 'system-ab-wheel-rollout',
            sets: [row('hold', reps: null, weightKg: null, durationSec: 60)],
          ),
        ],
      );

      expect(_file(workout).sets, const [
        StravaStrengthSet(exerciseType: 'AB_WHEEL_ROLLOUT', duration: 60),
      ]);
    });

    // Three sets of a single-arm row are six rows; Strava has no sides, so a
    // left and the right after it go as the one set they are.
    test('sends a left/right pair as one set', () {
      final workout = session(
        exercises: [
          exercise(
            templateId: 'system-single-arm-row',
            sets: [
              row('l1', reps: 10, side: SetSide.left),
              row('r1', reps: 9, side: SetSide.right),
              row('l2', side: SetSide.left),
              row('r2', side: SetSide.right),
            ],
          ),
        ],
      );

      final sets = _file(workout).sets;
      expect([for (final set in sets) set.repetitions], [10, 8]);
      expect(sets.every((set) => set.exerciseType == 'DUMBBELL_ROW'), isTrue);
    });

    test('keeps a right with no left before it', () {
      final rows = stravaUploadedRows([
        row('r1', side: SetSide.right),
        row('r2', side: SetSide.right),
      ]);
      expect([for (final r in rows) r.id], ['r1', 'r2']);
    });

    // A person's own exercise has no line in the table, so it goes as the
    // generic type for its primary muscle. One the library no longer has is
    // left out rather than guessed.
    test('maps a custom exercise by its primary muscle', () {
      final custom = customExercise('custom-1', {
        Muscles.triceps: MuscleTargetType.secondary,
        Muscles.chest: MuscleTargetType.primary,
      });
      final workout = session(
        exercises: [
          exercise(templateId: 'custom-1', sets: [row('a')]),
          exercise(templateId: 'deleted-custom', sets: [row('b')]),
        ],
      );

      expect(
        [
          for (final set in _file(workout, [custom]).sets) set.exerciseType,
        ],
        ['BENCH_PRESS_GENERIC'],
      );
    });

    test('is nothing when no exercise can be placed', () {
      final unplaced = customExercise('custom-2', {
        Muscles.triceps: MuscleTargetType.secondary,
      });
      final workout = session(
        exercises: [
          exercise(templateId: 'custom-2', sets: [row('a')]),
        ],
      );

      expect(StravaStrengthFile.from(workout, [unplaced]), isNull);
    });

    // A built-in exercise added to the bundle without a Strava type would
    // upload as nothing. Read from the Swift app's bundle, which the Flutter
    // catalogue embeds byte for byte.
    test('has a Strava type for every built-in exercise', () {
      final json = jsonDecode(
        File(
          '../../../Compound/SupportingFiles/Resources/'
          'PrebuiltExercises.json',
        ).readAsStringSync(),
      ) as Map<String, Object?>;
      final ids = [
        for (final exercise in json['exercises']! as List<Object?>)
          (exercise! as Map<String, Object?>)['id']! as String,
      ];

      expect(ids, isNotEmpty);
      expect(
        ids.where((id) => !stravaSystemExercises.containsKey(id)),
        isEmpty,
      );
    });

    test('has a generic Strava type for every muscle', () {
      expect([
        for (final muscle in Muscles.values)
          if (!stravaGenericByMuscle.containsKey(muscle)) muscle,
      ], isEmpty);
    });

    // Strava's format is snake_case with a fixed version. A set's missing
    // measures are left out, not sent null.
    test("encodes with Strava's keys", () {
      final json = _file(session()).toJson();

      expect(json['version'], '1.0');
      expect(json['start_time'], '2023-11-14T22:13:20Z');
      expect(json['elapsed_time'], 600);
      expect(json['active_time'], 600);
      expect(json['utc_offset'], isA<int>());
      expect(json['creator'], {'name': 'Compound'});
      final set = (json['sets']! as List).single as Map<String, Object?>;
      expect(set, {
        'exercise_type': 'BARBELL_BENCH_PRESS',
        'repetitions': 8,
        'weight': 100.0,
      });
      expect(set.containsKey('duration'), isFalse);
    });

    test('sets compare by value', () {
      const set = StravaStrengthSet(exerciseType: 'X', repetitions: 1);
      expect(set, const StravaStrengthSet(exerciseType: 'X', repetitions: 1));
      expect(
        set.hashCode,
        const StravaStrengthSet(exerciseType: 'X', repetitions: 1).hashCode,
      );
      expect(set, isNot(const StravaStrengthSet(exerciseType: 'Y')));
      expect('$set', 'StravaStrengthSet(X, 1, null, null)');
    });
  });

  group('stravaDescription', () {
    String? describe(
      WorkoutSessionModel workout, {
      WeightUnitPreference weightUnit = WeightUnitPreference.kilograms,
      DistanceUnitPreference distanceUnit = DistanceUnitPreference.kilometers,
    }) => stravaDescription(
      workout,
      weightUnit: weightUnit,
      distanceUnit: distanceUnit,
    );

    // The notes, then a line per exercise of what was uploaded: the same
    // sets the file carries.
    test('is the notes then the sets', () {
      final workout = session(
        notes: 'Felt strong',
        exercises: [
          exercise(
            name: 'Bench Press',
            sets: [
              row('w', weightKg: 60, isWarmup: true),
              row('a'),
              row('b', reps: 7, weightKg: 97.5),
            ],
          ),
          exercise(
            templateId: 'system-captains-chair-knee-raise',
            name: 'Knee Raise',
            sets: [row('c', reps: 12, weightKg: null)],
          ),
          exercise(
            templateId: 'system-ab-wheel-rollout',
            name: 'Plank',
            sets: [row('d', reps: null, weightKg: null, durationSec: 60)],
          ),
          exercise(name: 'Skipped', sets: [row('e', completed: false)]),
        ],
      );

      expect(
        describe(workout),
        'Felt strong\n\n'
        'Bench Press: 100 kg × 8, 97.5 kg × 7\n'
        'Knee Raise: 12 reps\n'
        'Plank: 1:00',
      );
    });

    test("uses the user's units", () {
      final workout = session(
        exercises: [
          exercise(name: 'Bench', sets: [row('a', reps: 5)]),
        ],
      );

      expect(
        describe(workout, weightUnit: WeightUnitPreference.pounds),
        'Bench: 220.5 lb × 5',
      );
    });

    test('uses the unit a set was lifted in, where it says', () {
      final workout = session(
        exercises: [
          exercise(
            name: 'Bench',
            sets: [
              row('a', reps: 5, weightUnit: ExerciseWeightUnit.kilograms),
              row('b', reps: 5, weightUnit: ExerciseWeightUnit.pounds),
            ],
          ),
        ],
      );

      expect(
        describe(workout, weightUnit: WeightUnitPreference.pounds),
        'Bench: 100 kg × 5, 220.5 lb × 5',
      );
    });

    test('says nothing when there is nothing to say', () {
      final workout = session(
        notes: '  ',
        exercises: [
          exercise(sets: [row('a', completed: false)]),
        ],
      );

      expect(describe(workout), isNull);
    });

    test('describes every kind of set as Swift does', () {
      final workout = session(
        exercises: [
          exercise(
            name: 'Mixed',
            sets: [
              row('rep', reps: 1, weightKg: null),
              row('weighted-hold', reps: null, durationSec: 45),
              row('long-hold', reps: null, weightKg: null, durationSec: 3930),
              row('carry', reps: null, weightKg: null, distanceMeters: 1250),
              row('no-distance', reps: null, weightKg: 0, distanceMeters: 0),
              row('load-only', reps: null, weightKg: 1234.25),
              row('negative', reps: 3, weightKg: -20),
              row('nothing', reps: null, weightKg: null),
            ],
          ),
        ],
      );

      expect(
        describe(workout),
        'Mixed: 1 rep, 100 kg × 0:45, 1:05:30, 1.2 km, 1,234.2 kg, 3 reps',
      );
      expect(
        describe(workout, distanceUnit: DistanceUnitPreference.miles),
        contains('0.8 mi'),
      );
    });
  });
}
