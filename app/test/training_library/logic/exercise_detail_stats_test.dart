import 'package:compound/training_library/training_library.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(ExerciseDetailStats, () {
    test('is empty without sessions', () {
      expect(ExerciseDetailStats.make(const [], 'Bench').isEmpty, isTrue);
    });

    test('becomes the history of finished sessions with the exercise', () {
      final stats = ExerciseDetailStats.make([
        fixtureSession(
          'a',
          exercises: [
            fixtureExercise(
              'Bench',
              sets: [
                fixtureSet(),
                fixtureSet(reps: 3, weightKg: 110),
                fixtureSet(reps: 10, weightKg: 60, isWarmup: true),
                fixtureSet(weightKg: 200, completed: false),
              ],
            ),
            fixtureExercise('Squat', sets: [fixtureSet(weightKg: 300)]),
          ],
        ),
        fixtureSession(
          'running',
          finished: false,
          exercises: [
            fixtureExercise('Bench', sets: [fixtureSet()]),
          ],
        ),
        fixtureSession(
          'warmups',
          exercises: [
            fixtureExercise('Bench', sets: [fixtureSet(isWarmup: true)]),
          ],
        ),
      ], 'Bench');

      final performance = stats.performances.single;
      expect(performance.sessionId, 'a');
      expect(performance.workoutName, 'Session a');
      expect(performance.workingSets, 2);
      expect(performance.totalReps, 8);
      expect(performance.volumeKg, 830);
      expect(performance.heaviestWeightKg, 110);
      expect(performance.repsAtHeaviest, 3);
    });

    test('at equal weight the set with more reps is the heaviest', () {
      final stats = ExerciseDetailStats.make([
        fixtureSession(
          'a',
          exercises: [
            fixtureExercise(
              'Bench',
              sets: [
                fixtureSet(reps: 3),
                fixtureSet(reps: 6),
                fixtureSet(reps: 0, weightKg: 150),
                fixtureSet(weightKg: 140, parentSetId: 'drop'),
                fixtureSet(weightKg: null),
              ],
            ),
          ],
        ),
      ], 'Bench');
      final performance = stats.performances.single;
      expect(performance.heaviestWeightKg, 100);
      expect(performance.repsAtHeaviest, 6);
      // A drop is part of its set, not a set of its own.
      expect(performance.workingSets, 4);
    });

    test('reads newest first', () {
      final stats = ExerciseDetailStats.make([
        for (final (id, day) in [('old', 2), ('new', 9), ('mid', 5)])
          fixtureSession(
            id,
            day: day,
            exercises: [
              fixtureExercise('Bench', sets: [fixtureSet()]),
            ],
          ),
      ], 'Bench');
      expect(stats.mostRecentFirst.map((p) => p.sessionId), [
        'new',
        'mid',
        'old',
      ]);
    });

    // Swift `ExerciseModelDetailPresenterTests`, the Charts and Records
    // cases.
    ExerciseDetailStats bench(
      List<(String, int, List<WorkoutSetModel>)> rows,
    ) => ExerciseDetailStats.make([
      for (final (id, day, sets) in rows)
        fixtureSession(
          id,
          day: day,
          exercises: [fixtureExercise('Bench', sets: sets)],
        ),
    ], 'Bench');

    test('sessions add up to all-time totals', () {
      final stats = bench([
        ('a', 2, [fixtureSet(), fixtureSet()]),
        ('b', 9, [fixtureSet()]),
      ]);
      expect(stats.performances, hasLength(2));
      expect(stats.totalSets, 3);
      expect(stats.totalReps, 15);
      expect(stats.totalVolumeKg, 1500);
    });

    test('the heaviest set is the heaviest ever', () {
      final stats = bench([
        ('a', 2, [fixtureSet(reps: 3, weightKg: 120)]),
        ('b', 9, [fixtureSet(reps: 8, weightKg: 90)]),
      ]);
      final heaviest = stats.heaviest!;
      expect(heaviest.heaviestWeightKg, 120);
      expect(heaviest.repsAtHeaviest, 3);
      expect(heaviest.date, stats.performances.first.date);
    });

    test('at equal weight more reps wins', () {
      final stats = bench([
        ('a', 2, [fixtureSet(reps: 3)]),
        ('b', 9, [fixtureSet(reps: 4), fixtureSet()]),
      ]);
      final heaviest = stats.heaviest!;
      expect(heaviest.heaviestWeightKg, 100);
      expect(heaviest.repsAtHeaviest, 5);
      expect(heaviest.sessionId, 'b');
    });

    test('nothing lifted has no heaviest set or best', () {
      final stats = bench([
        ('a', 2, [fixtureSet(weightKg: null)]),
      ]);
      expect(stats.heaviest, isNull);
      expect(stats.bestOneRepMaxKg, 0);
      expect(stats.oneRepMaxRecords, isEmpty);
    });

    test('the weight chart reads a point per session, oldest first', () {
      final stats = bench([
        ('b', 9, [fixtureSet(weightKg: 110)]),
        ('a', 2, [fixtureSet()]),
      ]);
      expect(stats.chronological.map((p) => p.heaviestWeightKg), [100, 110]);
    });

    test("the reps chart totals each session's reps", () {
      final stats = bench([
        ('a', 2, [fixtureSet(), fixtureSet(reps: 8)]),
      ]);
      expect(stats.chronological.map((p) => p.totalReps), [13]);
    });

    test('each session keeps its best estimated one-rep max', () {
      final stats = bench([
        ('a', 2, [fixtureSet(), fixtureSet(reps: 3, weightKg: 110, rpe: 8)]),
      ]);
      // 5 × 100 → 116.7; 3 at RPE 8 is 5 to failure, 110 → 128.3.
      expect(stats.bestOneRepMaxKg, closeTo(110 * (1 + 5 / 30), 1e-9));
    });

    test('only sessions beating every one before are records', () {
      final stats = bench([
        ('s1', 2, [fixtureSet()]),
        ('s2', 5, [fixtureSet(weightKg: 90)]),
        ('s3', 9, [fixtureSet(weightKg: 110)]),
      ]);
      expect(stats.oneRepMaxRecords.map((p) => p.sessionId), ['s3', 's1']);
    });

    test('equalling a best is not a record', () {
      final stats = bench([
        ('s1', 2, [fixtureSet()]),
        ('s2', 5, [fixtureSet()]),
      ]);
      expect(stats.oneRepMaxRecords.map((p) => p.sessionId), ['s1']);
    });

    test('more reps at the same weight is a record', () {
      final stats = bench([
        ('s1', 2, [fixtureSet()]),
        ('s2', 5, [fixtureSet(reps: 8)]),
      ]);
      expect(stats.oneRepMaxRecords.map((p) => p.sessionId), ['s2', 's1']);
    });
  });
}
