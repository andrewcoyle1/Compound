import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_history/workout_history.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// Mirrors the Swift app's `WorkoutSessionRowStatsTests`, `SetDetailRowTests`
/// and `SessionVolumeUnitTests`.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final es = lookupAppLocalizations(const Locale('es'));
  const locale = 'en';

  group('sessionVolume', () {
    test('counts working sets only and switches to tonnes', () {
      final light = fixtureSession(
        'a',
        exercises: [
          fixtureExercise(
            'Lift',
            sets: [
              fixtureSet(reps: 10, weightKg: 20, isWarmup: true),
              fixtureSet(reps: 10, weightKg: 50),
            ],
          ),
        ],
      );
      expect(WorkoutText.sessionVolume(light, locale: locale), '500\u00a0kg');

      final heavy = fixtureSession(
        'b',
        exercises: [
          fixtureExercise(
            'Lift',
            sets: [fixtureSet(), fixtureSet(weightKg: 150)],
          ),
        ],
      );
      expect(WorkoutText.sessionVolume(heavy, locale: locale), '1.3 t');

      final reps = fixtureSession(
        'c',
        exercises: [
          fixtureExercise(
            'Lift',
            mode: TrackingMode.repsOnly,
            sets: [fixtureSet(weightKg: null)],
          ),
        ],
      );
      expect(WorkoutText.sessionVolume(reps, locale: locale), isNull);
    });

    test('a pound total stays in pounds', () {
      final session = fixtureSession(
        'a',
        exercises: [
          fixtureExercise(
            'Lift',
            sets: [fixtureSet(reps: 10, weightUnit: 'pounds')],
          ),
        ],
      );
      expect(
        WorkoutText.sessionVolume(session, locale: locale),
        '2,204.6\u00a0lb',
      );
    });
  });

  group('exerciseSets', () {
    final session = fixtureSession('s');
    String describe(TrackingMode mode, List<WorkoutSetModel> sets) =>
        WorkoutText.exerciseSets(
          l10n,
          fixtureExercise('Lift', mode: mode, sets: sets),
          session,
          locale: locale,
        );

    test('each tracking mode describes its first working set', () {
      expect(
        describe(TrackingMode.weightReps, [
          fixtureSet(reps: 8, weightKg: 82.5),
          fixtureSet(reps: 8, weightKg: 82.5),
        ]),
        '2 × 8 @ 82.5\u00a0kg',
      );
      expect(
        describe(TrackingMode.weightReps, [
          fixtureSet(reps: 8, weightKg: null),
        ]),
        '1 × 8',
      );
      // A bodyweight set logged at 0 kg reads as its reps; assistance keeps
      // its load.
      expect(
        describe(TrackingMode.weightReps, [fixtureSet(reps: 8, weightKg: 0)]),
        '1 × 8',
      );
      expect(
        describe(TrackingMode.weightReps, [fixtureSet(reps: 8, weightKg: -20)]),
        '1 × 8 @ -20\u00a0kg',
      );
      expect(
        describe(TrackingMode.repsOnly, [fixtureSet(reps: 12, weightKg: null)]),
        '1 × 12',
      );
      expect(
        describe(TrackingMode.timeOnly, [
          fixtureSet(reps: null, durationSec: 45),
        ]),
        '1 × 0:45',
      );
      expect(
        describe(TrackingMode.distanceTime, [
          fixtureSet(reps: null, distanceMeters: 5000),
        ]),
        '1 × 5\u00a0km',
      );
    });

    test('falls back to a set count', () {
      expect(describe(TrackingMode.timeOnly, [fixtureSet(reps: 3)]), '1 set');
      expect(
        describe(TrackingMode.weightReps, [fixtureSet(reps: null)]),
        '1 set',
      );
      expect(
        describe(TrackingMode.repsOnly, [fixtureSet(reps: null)]),
        '1 set',
      );
      expect(
        describe(TrackingMode.distanceTime, [fixtureSet(reps: null)]),
        '1 set',
      );
      // Nothing logged: the planned sets.
      expect(
        describe(TrackingMode.weightReps, [fixtureSet(isWarmup: true)]),
        '0 sets',
      );
    });
  });

  group('recordDetail', () {
    PersonalRecord record(TrackingMode mode, double value, [int reps = 0]) =>
        PersonalRecord(
          exerciseName: 'Lift',
          trackingMode: mode,
          value: value,
          reps: reps,
          weightUnit: ExerciseWeightUnit.kilograms,
        );

    test('reads as the set does', () {
      String detail(PersonalRecord r) =>
          WorkoutText.recordDetail(l10n, r, locale: locale);
      expect(
        detail(record(TrackingMode.weightReps, 100, 5)),
        '100\u00a0kg × 5',
      );
      expect(detail(record(TrackingMode.repsOnly, 20)), '20 reps');
      expect(detail(record(TrackingMode.timeOnly, 90)), '1:30');
      expect(detail(record(TrackingMode.distanceTime, 5200)), '5.2\u00a0km');
    });
  });

  group('highlights', () {
    test('the weekly count shows from the second workout, with an '
        'ordinal', () {
      expect(WorkoutText.weeklyWorkout(l10n, 1), isNull);
      expect(WorkoutText.weeklyWorkout(l10n, 2), '2nd workout of the week');
      expect(WorkoutText.weeklyWorkout(l10n, 3), '3rd workout of the week');
      expect(WorkoutText.weeklyWorkout(l10n, 4), '4th workout of the week');
      expect(WorkoutText.weeklyWorkout(l10n, 11), '11th workout of the week');
      expect(WorkoutText.weeklyWorkout(l10n, 21), '21st workout of the week');
      expect(
        WorkoutText.weeklyWorkout(es, 3),
        '3.º entrenamiento de la semana',
      );
    });

    test('the streak shows from two weeks', () {
      expect(WorkoutText.streak(l10n, null), isNull);
      expect(WorkoutText.streak(l10n, 1), isNull);
      expect(WorkoutText.streak(l10n, 6), '6-week streak');
    });
  });

  group('setValue', () {
    String? value(
      WorkoutSetModel set,
      TrackingMode mode, {
      ExerciseWeightUnit unit = ExerciseWeightUnit.kilograms,
      AppDistanceUnit distance = AppDistanceUnit.kilometers,
    }) => WorkoutText.setValue(
      l10n,
      set,
      mode,
      weightUnit: unit,
      distanceUnit: distance,
      locale: locale,
    );

    test('weight and reps read as one line', () {
      expect(
        value(fixtureSet(reps: 8, weightKg: 82.5), TrackingMode.weightReps),
        '82.5\u00a0kg × 8 reps',
      );
    });

    test('a set logged in pounds reads in pounds', () {
      expect(
        value(
          fixtureSet(reps: 1),
          TrackingMode.weightReps,
          unit: ExerciseWeightUnit.pounds,
        ),
        '220.5\u00a0lb × 1 rep',
      );
    });

    test('a set with no weight shows nothing', () {
      expect(
        value(fixtureSet(weightKg: null), TrackingMode.weightReps),
        isNull,
      );
    });

    test('reps, time and distance read in their own terms', () {
      expect(value(fixtureSet(reps: 12), TrackingMode.repsOnly), '12 reps');
      expect(value(fixtureSet(reps: null), TrackingMode.repsOnly), isNull);
      expect(value(fixtureSet(durationSec: 45), TrackingMode.timeOnly), '0:45');
      expect(
        value(
          fixtureSet(durationSec: 1530, distanceMeters: 402.336),
          TrackingMode.distanceTime,
          distance: AppDistanceUnit.miles,
        ),
        '0.2\u00a0mi in 25:30',
      );
      expect(
        value(fixtureSet(distanceMeters: 2000), TrackingMode.distanceTime),
        '2\u00a0km',
      );
      expect(
        value(fixtureSet(durationSec: 60), TrackingMode.distanceTime),
        '1:00',
      );
      expect(value(fixtureSet(), TrackingMode.distanceTime), isNull);
    });
  });

  test('every set kind but standard has a name', () {
    expect(WorkoutText.setKind(l10n, SetKind.standard), isNull);
    expect(
      [
        for (final kind in SetKind.values.skip(1))
          WorkoutText.setKind(l10n, kind),
      ],
      [
        'Drop set',
        'AMRAP',
        'Myo-reps',
        'Rest-pause',
        'Cluster',
        'Partials',
        'Stretch',
        'Hold',
      ],
    );
  });

  test('an exercise summary counts its sets and volume in its unit', () {
    expect(
      WorkoutText.exerciseSummary(
        l10n,
        fixtureExercise(
          'Lift',
          sets: [
            fixtureSet(isWarmup: true),
            fixtureSet(side: 'left'),
            fixtureSet(side: 'right'),
          ],
          weightUnit: ExerciseWeightUnit.pounds,
        ),
        locale: locale,
      ),
      '1 set · 2,204.6\u00a0lb volume',
    );
  });

  test('units follow the profile, metric when unset', () {
    expect(
      WorkoutText.preferredWeightUnit(WeightUnitPreference.pounds),
      AppWeightUnit.pounds,
    );
    expect(WorkoutText.preferredWeightUnit(null), AppWeightUnit.kilograms);
    expect(
      WorkoutText.preferredDistanceUnit(DistanceUnitPreference.miles),
      AppDistanceUnit.miles,
    );
    expect(WorkoutText.preferredDistanceUnit(null), AppDistanceUnit.kilometers);
  });

  test('session volume in the user unit (SessionVolumeUnitTests)', () {
    // 100 kg × 10 and 225 lb × 5 = 1,510.3 kg or 3,329.6 lb.
    final session = fixtureSession(
      's',
      exercises: [
        fixtureExercise('kg', sets: [fixtureSet(reps: 10)]),
        fixtureExercise(
          'lb',
          sets: [fixtureSet(weightKg: 225 / AppFormat.poundsPerKilogram)],
        ),
      ],
    );
    expect(
      AppFormat.weight(
        session.loggedVolumeKg,
        AppWeightUnit.pounds,
        locale: locale,
      ),
      '3,329.6\u00a0lb',
    );
    expect(
      AppFormat.weight(
        session.loggedVolumeKg,
        AppWeightUnit.kilograms,
        locale: locale,
      ),
      '1,510.3\u00a0kg',
    );
  });
}
