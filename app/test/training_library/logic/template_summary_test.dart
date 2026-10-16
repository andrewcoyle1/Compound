import 'package:compound/training_library/training_library.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  String name(Muscles muscle) => muscle.value;
  final bench = fixtureLibraryExercise(
    'bench',
    muscles: {
      Muscles.chest: MuscleTargetType.primary,
      Muscles.triceps: MuscleTargetType.secondary,
    },
  );
  final dips = fixtureLibraryExercise(
    'dips',
    muscles: {Muscles.triceps: MuscleTargetType.primary},
  );

  SetTarget target(int? min, int? max, [int? rir]) => SetTarget(
    id: '$min-$max-$rir',
    setNumber: 1,
    minReps: min,
    maxReps: max,
    rirTarget: rir,
  );

  group(TemplateSummary, () {
    test('plans whole sets for primary muscles, half for secondary', () {
      final summaries = TemplateSummary.targetMuscles([
        fixtureSlot(bench),
        fixtureSlot(dips, sets: 2),
        fixtureSlot(dips, sets: 0),
      ], name);
      expect(summaries, const [
        TargetMuscleSummary(Muscles.chest, 3, 1),
        TargetMuscleSummary(Muscles.triceps, 3.5, 2),
      ]);
    });

    test('tags a muscle primary when any exercise works it directly', () {
      final template = fixtureTemplate(
        'push',
        exercises: [fixtureSlot(bench), fixtureSlot(dips)],
      );
      expect(TemplateSummary.muscleTags(template, name), [
        (Muscles.chest, MuscleTargetType.primary),
        (Muscles.triceps, MuscleTargetType.primary),
      ]);
      expect(TemplateSummary.sortedMuscles(bench.muscleGroups, name), [
        (Muscles.chest, MuscleTargetType.primary),
        (Muscles.triceps, MuscleTargetType.secondary),
      ]);
    });

    test('sorts primary muscles first, then by name', () {
      expect(
        TemplateSummary.sortedMuscles(const {
          Muscles.triceps: MuscleTargetType.secondary,
          Muscles.abs: MuscleTargetType.secondary,
          Muscles.quads: MuscleTargetType.primary,
        }, name),
        [
          (Muscles.quads, MuscleTargetType.primary),
          (Muscles.abs, MuscleTargetType.secondary),
          (Muscles.triceps, MuscleTargetType.secondary),
        ],
      );
    });

    test('summarises the targets, leaving out what the plan does not set', () {
      expect(TemplateSummary.targets([target(8, 10, 1), target(6, 12, 2)]), (
        sets: 2,
        repsLow: 6,
        repsHigh: 12,
        rirLow: 1,
        rirHigh: 2,
      ));
      expect(TemplateSummary.targets([target(null, 12)]), (
        sets: 1,
        repsLow: 1,
        repsHigh: 12,
        rirLow: null,
        rirHigh: null,
      ));
      expect(TemplateSummary.targets([target(8, null)]), (
        sets: 1,
        repsLow: 8,
        repsHigh: null,
        rirLow: null,
        rirHigh: null,
      ));
      expect(TemplateSummary.targets([target(null, null)]), (
        sets: 1,
        repsLow: null,
        repsHigh: null,
        rirLow: null,
        rirHigh: null,
      ));
    });

    test('letters supersets in the order they first appear', () {
      final exercises = [
        fixtureSlot(bench, id: '1', supersetGroupId: 'b'),
        fixtureSlot(dips, id: '2', supersetGroupId: 'b'),
        fixtureSlot(bench, id: '3', supersetGroupId: 'alone'),
        fixtureSlot(dips, id: '4', supersetGroupId: 'a'),
        fixtureSlot(bench, id: '5', supersetGroupId: 'a'),
        fixtureSlot(dips, id: '6'),
      ];
      expect(TemplateSummary.supersetLetters(exercises), {'b': 'A', 'a': 'B'});
    });

    test('stops lettering after Z', () {
      final exercises = [
        for (var group = 0; group < 27; group++) ...[
          fixtureSlot(bench, id: '$group-1', supersetGroupId: '$group'),
          fixtureSlot(dips, id: '$group-2', supersetGroupId: '$group'),
        ],
      ];
      final letters = TemplateSummary.supersetLetters(exercises);
      expect(letters.length, 26);
      expect(letters['25'], 'Z');
    });

    test('names alternatives from the library and skips unknown ids', () {
      expect(
        TemplateSummary.alternativeNames(
          fixtureSlot(bench, substitutes: ['dips', 'gone']),
          [bench, dips],
        ),
        ['dips'],
      );
    });
  });
}
