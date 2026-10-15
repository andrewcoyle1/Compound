// ProgressCarouselMetricsTests: recent records and the weekly tally. The
// energy averages are compound_maths' comparedAverages, tested there.
import 'package:compound/progress/logic/progress_carousel.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  List<String> names(RecordKind kind, List<WorkoutSessionModel> sessions) => [
    for (final record in recentRecords(kind, sessions))
      '${record.name} ${record.value.toInt()}',
  ];

  group('recent records', () {
    test('come most recently set first', () {
      final sessions = [
        fixtureSession(
          'a',
          exercises: [
            fixtureExercise('Bench', sets: [fixtureSet()]),
            fixtureExercise('Squat', sets: [fixtureSet(weightKg: 140)]),
          ],
        ),
        fixtureSession(
          'b',
          day: 9,
          exercises: [
            fixtureExercise('Squat', sets: [fixtureSet(weightKg: 150)]),
          ],
        ),
      ];
      expect(names(RecordKind.oneRepMax, sessions), ['Squat 175', 'Bench 116']);
    });

    test('a matched record keeps its date', () {
      final sessions = [
        fixtureSession(
          'a',
          exercises: [
            fixtureExercise('Bench', sets: [fixtureSet(reps: 12)]),
          ],
        ),
        fixtureSession(
          'b',
          day: 5,
          exercises: [
            fixtureExercise('Curl', sets: [fixtureSet(reps: 10)]),
          ],
        ),
        fixtureSession(
          'c',
          day: 9,
          exercises: [
            fixtureExercise('Bench', sets: [fixtureSet(reps: 12)]),
          ],
        ),
      ];
      expect(names(RecordKind.reps, sessions), ['Curl 10', 'Bench 12']);
    });

    test('volume counts finished working sets and both sides', () {
      final sessions = [
        fixtureSession(
          'a',
          exercises: [
            fixtureExercise(
              'Lunge',
              sets: [
                fixtureSet(reps: 10, weightKg: 20, side: 'both'),
                fixtureSet(reps: 10, weightKg: 60, isWarmup: true),
                fixtureSet(reps: 10, weightKg: 60, completed: false),
              ],
            ),
          ],
        ),
      ];
      expect(names(RecordKind.volume, sessions), ['Lunge 400']);
    });

    test('a lift with nothing to count sets no record', () {
      final sessions = [
        fixtureSession(
          'a',
          exercises: [
            fixtureExercise(
              'Plank',
              sets: [fixtureSet(reps: null, weightKg: null)],
            ),
          ],
        ),
      ];
      for (final kind in RecordKind.values) {
        expect(names(kind, sessions), isEmpty, reason: kind.name);
      }
    });

    test('ties on the date go by name, and at most seven are kept', () {
      final sessions = [
        fixtureSession(
          'a',
          exercises: [
            for (final name in ['H', 'G', 'F', 'E', 'D', 'C', 'B', 'A'])
              fixtureExercise(name, sets: [fixtureSet()]),
          ],
        ),
      ];
      expect(
        [for (final r in recentRecords(RecordKind.reps, sessions)) r.name],
        ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
      );
    });
  });

  test('the tally counts a pair once and each muscle once', () {
    final sessions = [
      fixtureSession(
        'a',
        exercises: [
          fixtureExercise(
            'Row',
            sets: [
              fixtureSet(side: 'left'),
              fixtureSet(side: 'right'),
              fixtureSet(isWarmup: true),
            ],
          ),
          fixtureExercise('Pulldown', sets: [fixtureSet(), fixtureSet()]),
          fixtureExercise('Skipped', sets: [fixtureSet(completed: false)]),
        ],
      ),
    ];
    final tally = workoutTally(sessions, {
      'Row': fixtureLibraryExercise(
        'Row',
        muscles: const {
          Muscles.upperBack: MuscleTargetType.primary,
          Muscles.biceps: MuscleTargetType.secondary,
        },
      ),
      'Pulldown': fixtureLibraryExercise(
        'Pulldown',
        muscles: const {
          Muscles.lats: MuscleTargetType.primary,
          Muscles.biceps: MuscleTargetType.secondary,
        },
      ),
    });
    expect(tally, (muscles: 3, sets: 3, exercises: 2));
  });
}
