import 'package:compound/workout_history/workout_history.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// Mirrors the Swift app's `WorkoutSessionHighlightsTests`.
void main() {
  List<String> records(
    WorkoutSessionModel current,
    List<WorkoutSessionModel> prior,
  ) => [
    for (final record in WorkoutSessionHighlights.personalRecords(
      current,
      priorSessions: prior,
    ))
      '${record.exerciseName} ${record.value} × ${record.reps}',
  ];

  group('personalRecords', () {
    test('a heavier set than ever before is a record', () {
      final before = fixtureSession(
        'a',
        exercises: [
          fixtureExercise('Bench', sets: [fixtureSet(reps: 8, weightKg: 95)]),
        ],
      );
      final now = fixtureSession(
        'b',
        day: 9,
        exercises: [
          fixtureExercise('Bench', sets: [fixtureSet(reps: 3)]),
        ],
      );
      expect(records(now, [before]), ['Bench 100.0 × 3']);
    });

    test('equal weight with more reps is a record', () {
      final before = fixtureSession(
        'a',
        exercises: [
          fixtureExercise('Bench', sets: [fixtureSet()]),
        ],
      );
      final now = fixtureSession(
        'b',
        day: 9,
        exercises: [
          fixtureExercise('Bench', sets: [fixtureSet(reps: 6)]),
        ],
      );
      expect(records(now, [before]), ['Bench 100.0 × 6']);
    });

    test('matching the best is not a record', () {
      final before = fixtureSession(
        'a',
        exercises: [
          fixtureExercise('Bench', sets: [fixtureSet()]),
        ],
      );
      final now = fixtureSession(
        'b',
        day: 9,
        exercises: [
          fixtureExercise(
            'Bench',
            sets: [fixtureSet(), fixtureSet(reps: 10, weightKg: 90)],
          ),
        ],
      );
      expect(records(now, [before]), isEmpty);
    });

    test('a first-ever lift is not a record', () {
      final now = fixtureSession(
        'b',
        day: 9,
        exercises: [
          fixtureExercise('Bench', sets: [fixtureSet()]),
          fixtureExercise('Squat', sets: [fixtureSet()]),
        ],
      );
      expect(records(now, []), isEmpty);
      expect(records(now, [now]), isEmpty);
    });

    test('later sessions, other authors and rest days are ignored', () {
      final before = fixtureSession(
        'a',
        exercises: [
          fixtureExercise('Bench', sets: [fixtureSet(weightKg: 90)]),
        ],
      );
      final later = fixtureSession(
        'c',
        day: 16,
        exercises: [
          fixtureExercise('Bench', sets: [fixtureSet(weightKg: 150)]),
        ],
      );
      final someoneElse = fixtureSession(
        'd',
        day: 3,
        author: 'other',
        exercises: [
          fixtureExercise('Bench', sets: [fixtureSet(weightKg: 150)]),
        ],
      );
      final rest = fixtureSession(
        'r',
        day: 4,
        isRestDay: true,
        exercises: [
          fixtureExercise('Bench', sets: [fixtureSet(weightKg: 150)]),
        ],
      );
      final now = fixtureSession(
        'b',
        day: 9,
        exercises: [
          fixtureExercise('Bench', sets: [fixtureSet()]),
        ],
      );
      expect(records(now, [before, later, someoneElse, rest]), [
        'Bench 100.0 × 5',
      ]);
    });

    test('warm-ups, open sets, sub-sets and unfinished sessions do not '
        'count', () {
      final before = fixtureSession(
        'a',
        exercises: [
          fixtureExercise('Bench', sets: [fixtureSet(weightKg: 90)]),
        ],
      );
      final abandoned = fixtureSession(
        'x',
        day: 3,
        finished: false,
        exercises: [
          fixtureExercise('Bench', sets: [fixtureSet(weightKg: 150)]),
        ],
      );
      final now = fixtureSession(
        'b',
        day: 9,
        exercises: [
          fixtureExercise(
            'Bench',
            sets: [
              fixtureSet(weightKg: 95),
              fixtureSet(weightKg: 200, isWarmup: true),
              fixtureSet(weightKg: 180, completed: false),
              fixtureSet(weightKg: 190, parentSetId: 'p'),
              fixtureSet(weightKg: 190, reps: 0),
              fixtureSet(weightKg: 0, reps: 20),
            ],
          ),
        ],
      );
      expect(records(now, [before, abandoned]), ['Bench 95.0 × 5']);
    });

    test('at most three records are shown, each exercise once', () {
      final names = ['Bench', 'Squat', 'Deadlift', 'Row'];
      final before = fixtureSession(
        'a',
        exercises: [
          for (final name in names)
            fixtureExercise(name, sets: [fixtureSet(weightKg: 50)]),
        ],
      );
      final now = fixtureSession(
        'b',
        day: 9,
        exercises: [
          fixtureExercise('Bench', sets: [fixtureSet(weightKg: 60)]),
          for (final name in names)
            fixtureExercise(name, sets: [fixtureSet(weightKg: 60)]),
        ],
      );
      expect(records(now, [before]), [
        'Bench 60.0 × 5',
        'Squat 60.0 × 5',
        'Deadlift 60.0 × 5',
      ]);
    });

    test('reps-only, timed and distance exercises compare their own '
        'measure', () {
      final before = fixtureSession(
        'a',
        exercises: [
          fixtureExercise(
            'Pull Up',
            mode: TrackingMode.repsOnly,
            sets: [fixtureSet(reps: 10, weightKg: null)],
          ),
          fixtureExercise(
            'Plank',
            mode: TrackingMode.timeOnly,
            sets: [fixtureSet(reps: null, weightKg: null, durationSec: 60)],
          ),
          fixtureExercise(
            'Row Erg',
            mode: TrackingMode.distanceTime,
            sets: [
              fixtureSet(reps: null, weightKg: null, distanceMeters: 1000),
            ],
          ),
        ],
      );
      final now = fixtureSession(
        'b',
        day: 9,
        exercises: [
          fixtureExercise(
            'Pull Up',
            mode: TrackingMode.repsOnly,
            sets: [fixtureSet(reps: 12, weightKg: null)],
          ),
          fixtureExercise(
            'Plank',
            mode: TrackingMode.timeOnly,
            sets: [fixtureSet(reps: null, weightKg: null, durationSec: 90)],
          ),
          fixtureExercise(
            'Row Erg',
            mode: TrackingMode.distanceTime,
            sets: [fixtureSet(reps: null, weightKg: null)],
          ),
        ],
      );
      expect(records(now, [before]), ['Pull Up 12.0 × 0', 'Plank 90.0 × 0']);
    });

    test('a record is in the unit the set, exercise or session used', () {
      PersonalRecord recordFor(WorkoutExerciseModel exercise) =>
          WorkoutSessionHighlights.personalRecords(
            fixtureSession('b', day: 9, exercises: [exercise]),
            priorSessions: [
              fixtureSession(
                'a',
                exercises: [
                  fixtureExercise('Bench', sets: [fixtureSet(weightKg: 50)]),
                ],
              ),
            ],
          ).single;

      expect(
        recordFor(
          fixtureExercise('Bench', sets: [fixtureSet(weightUnit: 'pounds')]),
        ).weightUnit,
        ExerciseWeightUnit.pounds,
      );
      expect(
        recordFor(
          fixtureExercise(
            'Bench',
            sets: [fixtureSet()],
            weightUnit: ExerciseWeightUnit.pounds,
          ),
        ).weightUnit,
        ExerciseWeightUnit.pounds,
      );
      expect(
        recordFor(fixtureExercise('Bench', sets: [fixtureSet()])).weightUnit,
        ExerciseWeightUnit.kilograms,
      );
    });
  });

  group('weeklyWorkoutNumber', () {
    final now = fixtureSession('now', day: 5);
    final history = [
      fixtureSession('mon'),
      fixtureSession('tue', day: 3),
      fixtureSession('rest', day: 3, isRestDay: true),
      fixtureSession('open', day: 4, finished: false),
      fixtureSession('theirs', day: 4, author: 'other'),
      fixtureSession('lastWeek', day: 1),
      fixtureSession('laterThisWeek', day: 7),
      now,
    ];

    test('counts only finished, non-rest sessions earlier that week', () {
      expect(
        WorkoutSessionHighlights.weeklyWorkoutNumber(
          now,
          history: history,
          firstDayOfWeek: 1,
        ),
        3,
      );
    });

    test('a Sunday start puts the 1st in the same week', () {
      expect(
        WorkoutSessionHighlights.weeklyWorkoutNumber(
          now,
          history: history,
          firstDayOfWeek: 0,
        ),
        4,
      );
    });

    test('weeks start at midnight on their first day', () {
      expect(
        WorkoutSessionHighlights.weekStart(DateTime(2026, 3, 8, 23), 1),
        DateTime(2026, 3, 2),
      );
      expect(
        WorkoutSessionHighlights.weekStart(DateTime(2026, 3, 8, 23), 0),
        DateTime(2026, 3, 8),
      );
    });
  });
}
