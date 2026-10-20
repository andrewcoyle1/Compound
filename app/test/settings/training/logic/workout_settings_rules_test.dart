import 'package:compound/settings/training/logic/workout_settings_rules.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/helpers.dart';

void main() {
  const settings = WorkoutSettings(authorId: 'u');

  group('WorkoutSettingsReading', () {
    test('reads missing optionals as Swift does', () {
      expect(settings.showsOnLockScreen, isTrue);
      expect(settings.plansSets, isFalse);
      expect(settings.raisesAmrapTarget, isTrue);
      expect(settings.amrapWeightCeiling, 12);
      expect(settings.addsWeightAtAmrapTarget, isTrue);
    });

    test('reads what is stored', () {
      const stored = WorkoutSettings(
        authorId: 'u',
        showOnLockScreen: false,
        setPlanning: true,
        amrapRaisesTarget: false,
        amrapAddsWeightAtTarget: 15,
        amrapAddsWeight: false,
      );
      expect(stored.showsOnLockScreen, isFalse);
      expect(stored.plansSets, isTrue);
      expect(stored.raisesAmrapTarget, isFalse);
      expect(stored.amrapWeightCeiling, 15);
      expect(stored.addsWeightAtAmrapTarget, isFalse);
    });

    test("an older build's never-adds-weight reads as 12 and off", () {
      const legacy = WorkoutSettings(
        authorId: 'u',
        amrapAddsWeightAtTarget: WorkoutSettingsReading.legacyNeverAddsWeight,
      );
      expect(legacy.amrapWeightCeiling, 12);
      expect(legacy.addsWeightAtAmrapTarget, isFalse);
    });

    test('each kind reads its own rest, falling back to the older one', () {
      expect(settings.intraSetRest(IntraSetKind.myo), 15);
      expect(settings.intraSetRest(IntraSetKind.restPause), 20);
      expect(settings.intraSetRest(IntraSetKind.cluster), 15);
      const older = WorkoutSettings(authorId: 'u', intraSetRestSeconds: 12);
      expect(
        [for (final kind in IntraSetKind.values) older.intraSetRest(kind)],
        [12, 12, 12],
      );
      const own = WorkoutSettings(
        authorId: 'u',
        intraSetRestSeconds: 12,
        intraSetRestMyoSeconds: 10,
        intraSetRestPauseSeconds: 30,
        intraSetRestClusterSeconds: 20,
      );
      expect(
        [for (final kind in IntraSetKind.values) own.intraSetRest(kind)],
        [10, 30, 20],
      );
    });

    test('the rest-pause row offers longer rests', () {
      expect(IntraSetKind.myo.options, [10, 15, 20]);
      expect(IntraSetKind.restPause.options, [15, 20, 30]);
      expect(IntraSetKind.cluster.options, [10, 15, 20]);
    });

    test("a type's rest is the user's, else the tracker's default", () {
      expect(
        [for (final type in ExerciseType.values) settings.restDuration(type)],
        [120, 120, 90, 90, 60],
      );
      const own = WorkoutSettings(
        authorId: 'u',
        restDurationsByExerciseType: {'core': 45},
      );
      expect(own.restDuration(ExerciseType.core), 45);
    });

    test('each scaling is read from its own setting', () {
      const scaled = WorkoutSettings(
        authorId: 'u',
        warmUpRestScaling: 0.5,
        betweenExercisesRestScaling: 1.25,
        sideSetRestScaling: 2,
      );
      expect(
        [for (final s in RestScaling.values) s.of(scaled)],
        [0.5, 1.25, 2.0],
      );
    });
  });

  test('withFields sets fields and clears an optional with null', () {
    const stored = WorkoutSettings(
      authorId: 'u',
      supersetTransitionRestSeconds: 15,
    );
    final changed = withFields(stored, {
      WorkoutSettingsKeys.rirTracking: true,
      WorkoutSettingsKeys.supersetTransitionRestSeconds: null,
    });
    expect(changed.rirTracking, isTrue);
    expect(changed.supersetTransitionRestSeconds, isNull);
  });

  test('the AMRAP ceiling holds to its range', () {
    expect(amrapCeilingChange(15), {
      WorkoutSettingsKeys.amrapAddsWeightAtTarget: 15,
    });
    expect(amrapCeilingChange(40), {
      WorkoutSettingsKeys.amrapAddsWeightAtTarget: 20,
    });
    expect(amrapCeilingChange(2), {
      WorkoutSettingsKeys.amrapAddsWeightAtTarget: 8,
    });
  });

  group('exercise rest overrides', () {
    test('are named, sorted, and drop exercises no longer there', () {
      final library = [
        fixtureLibraryExercise('b', name: 'Bench'),
        fixtureLibraryExercise('a', name: 'Squat'),
      ];
      final overrides = exerciseRestOverrides(const [
        ExerciseSettingsModel(id: 'a', authorId: 'u', restDurationOverride: 60),
        ExerciseSettingsModel(id: 'b', authorId: 'u', restDurationOverride: 90),
        ExerciseSettingsModel(id: 'b2', authorId: 'u', note: 'only a note'),
        ExerciseSettingsModel(
          id: 'gone',
          authorId: 'u',
          restDurationOverride: 30,
        ),
      ], library);
      expect(overrides, [
        (id: 'b', name: 'Bench', seconds: 90),
        (id: 'a', name: 'Squat', seconds: 60),
      ]);
      expect(
        exercisesWithoutRestOverride(
          overrides.take(1).toList(),
          library,
        ).map((e) => e.id),
        ['a'],
      );
    });
  });
}
