import 'dart:convert';
import 'dart:io';

import 'package:compound_models/compound_models.dart' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

import '../helpers/fixtures.dart';

m.WorkoutSessionModel _fixture(String name) =>
    m.WorkoutSessionModel.fromFirestore(
      m.taggedJsonToFirestore(
        jsonDecode(
          File('../../../contracts/firestore/workout_session/$name.json')
              .readAsStringSync(),
        ) as Map<String, Object?>,
      ),
    );

void main() {
  group('enums', () {
    test('every stored value has a rules value of the same name, and back', () {
      for (final mode in m.TrackingMode.values) {
        expect(mode.rules.name, mode.name);
      }
      for (final side in m.SetSide.values) {
        expect(side.rules.model, side);
      }
      for (final kind in m.SetKind.values) {
        expect(kind.rules.model, kind);
      }
      for (final unit in m.ExerciseWeightUnit.values) {
        expect(unit.rules.model, unit);
      }
      for (final type in m.ExerciseType.values) {
        expect(type.rules.name, type.name);
      }
      for (final type in m.SetTargetSetType.values) {
        expect(type.rules.name, type.name);
      }
      for (final mode in m.ProgressionAdjustmentMode.values) {
        expect(mode.rules.name, mode.name);
      }
      for (final kind in m.EquipmentKind.values) {
        expect(rulesRef(ref(kind, 'x')).kind.name, kind.name);
      }
    });
  });

  group('a session there and back', () {
    for (final name in [
      'full',
      'minimal',
      'legacy-lenient-nested.expected',
      'legacy-null-optionals.expected',
    ]) {
      test('loses nothing of the $name fixture', () {
        final stored = _fixture(name);
        final rules = rulesSession(stored);

        final back = stored.copyWith(
          exercises: modelExercises(
            rules.exercises,
            exercises: stored.exercises,
            now: DateTime.utc(2030),
          ),
        );

        expect(
          m.firestoreToTaggedJson(back.toFirestore()),
          m.firestoreToTaggedJson(stored.toFirestore()),
        );
      });
    }

    test('carries every field the rules read', () {
      final stored = _fixture('full');
      final exercise = stored.exercises.first;
      final storedSet = exercise.sets.first;

      final rules = rulesExercise(exercise);
      final rulesFirst = rules.sets.first;

      expect(rules.id, exercise.id);
      expect(rules.templateId, exercise.templateId);
      expect(rules.name, exercise.name);
      expect(rules.index, exercise.index);
      expect(rules.supersetGroupId, exercise.supersetGroupId);
      expect(rules.restSeconds, exercise.restSeconds);
      expect(rules.loadsPerSet, exercise.loadsPerSet);
      expect(rules.weightUnit?.name, exercise.weightUnit?.name);
      expect(rules.setTargets, hasLength(exercise.setTargets.length));
      expect(
        rules.resistanceEquipment?.map((e) => e.equipmentId),
        exercise.activeVariation?.resistanceEquipment.map((e) => e.equipmentId),
      );
      expect(rulesFirst.reps, storedSet.reps);
      expect(rulesFirst.weightKg, storedSet.weightKg);
      expect(rulesFirst.rpe, storedSet.rpe);
      expect(rulesFirst.completedAt, storedSet.completedAt);
      expect(rulesFirst.isWarmup, storedSet.isWarmup);
      expect(rulesSession(stored).isDeload, stored.isDeload);
      final storedTarget = exercise.setTargets.first;
      final rulesTargetValue = rulesTarget(storedTarget);
      expect(rulesTargetValue.minReps, storedTarget.minReps);
      expect(rulesTargetValue.maxReps, storedTarget.maxReps);
      expect(rulesTargetValue.rirTarget, storedTarget.rirTarget);
      expect(rulesTargetValue.amrapTargetReps, storedTarget.amrapTargetReps);
      expect(rulesTargetValue.setType.name, storedTarget.setType.name);
    });
  });

  group('modelSet', () {
    final now = DateTime.utc(2030);

    test('keeps a side, kind or unit a newer build stored, when unchanged', () {
      final stored = set(
        's',
        side: 'top',
        kind: 'superDrop',
      ).copyWith(weightUnitRawValue: 'stones');
      final rules = rulesSet(stored);
      expect(rules.side, isNull);
      expect(rules.kind, r.SetKind.standard);

      final back = modelSet(rules, original: stored, now: now);

      expect(back.sideRawValue, 'top');
      expect(back.kindRawValue, 'superDrop');
      expect(back.weightUnitRawValue, 'stones');
      expect(back.dateCreated, stored.dateCreated);
    });

    test('writes what the rules changed as Swift would', () {
      final stored = set('s', kind: 'drop', side: 'left');
      final changed = rulesSet(stored).copyWith(
        kind: r.SetKind.standard,
        side: r.SetSide.right,
        weightUnit: r.WeightUnit.pounds,
      );

      final back = modelSet(changed, original: stored, now: now);

      // Swift stores a standard set's kind as nothing.
      expect(back.kindRawValue, isNull);
      expect(back.sideRawValue, 'right');
      expect(back.weightUnitRawValue, 'pounds');
    });

    test('creates a set the rules made at now', () {
      const made = r.WorkoutSet(
        id: 'new',
        authorId: author,
        kind: r.SetKind.drop,
        side: r.SetSide.both,
        parentSetId: 'p',
      );

      final back = modelSet(made, original: null, now: now);

      expect(back.dateCreated, now);
      expect(back.kindRawValue, 'drop');
      expect(back.sideRawValue, 'both');
      expect(back.parentSetId, 'p');
    });
  });

  test('modelExercises follows the rules order and drops the unknown', () {
    final a = exercise('a');
    final b = exercise('b');

    final back = modelExercises(
      [
        rulesExercise(b),
        const r.WorkoutExercise(id: 'ghost'),
        rulesExercise(a),
      ],
      exercises: [a, b],
      now: start,
    );

    expect(back.map((e) => e.id), ['b', 'a']);
  });

  group('rulesSettings', () {
    test('reads the rests by type it knows and leaves out the rest', () {
      const stored = m.WorkoutSettings(
        authorId: author,
        restDurationsByExerciseType: {'core': 45, 'rowing': 300},
        defaultRestDurationSeconds: 75,
        supersetTransitionRestSeconds: 10,
        intraSetRestSeconds: 12,
        intraSetRestMyoSeconds: 13,
        intraSetRestPauseSeconds: 14,
        intraSetRestClusterSeconds: 16,
        warmUpRestScaling: 0.5,
        betweenExercisesRestScaling: 1.5,
        sideSetRestScaling: 0.25,
        setPlanning: true,
        amrapRaisesTarget: false,
        amrapAddsWeightAtTarget: 10,
        amrapAddsWeight: true,
        restAfterLastWarmUp: false,
        restBetweenExercises: false,
        restBetweenSideSets: true,
        useRestTimers: false,
        supersetAutoScroll: false,
        exerciseAutoNext: false,
      );

      final rules = rulesSettings(stored);

      expect(rules.restDurationsByExerciseType, {r.ExerciseType.core: 45});
      expect(rules.defaultRestDurationSeconds, 75);
      expect(rules.supersetTransitionRestSeconds, 10);
      expect(rules.intraSetRest(r.SetKind.myo), 13);
      expect(rules.intraSetRest(r.SetKind.restPause), 14);
      expect(rules.intraSetRest(r.SetKind.cluster), 16);
      expect(rules.intraSetRestSeconds, 12);
      expect(rules.warmUpRestScaling, 0.5);
      expect(rules.betweenExercisesRestScaling, 1.5);
      expect(rules.sideSetRestScaling, 0.25);
      expect(rules.plansSets, isTrue);
      expect(rules.raisesAmrapTarget, isFalse);
      expect(rules.amrapWeightCeiling, 10);
      expect(rules.addsWeightAtAmrapTarget, isTrue);
      expect(rules.restAfterLastWarmUp, isFalse);
      expect(rules.restBetweenExercises, isFalse);
      expect(rules.restBetweenSideSets, isTrue);
      expect(rules.useRestTimers, isFalse);
      expect(rules.supersetAutoScroll, isFalse);
      expect(rules.exerciseAutoNext, isFalse);
    });
  });
}
