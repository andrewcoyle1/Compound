import 'package:compound/training_library/training_library.dart';
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
  });
}
