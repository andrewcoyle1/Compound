import 'package:compound/create_exercise/create_exercise.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors `ExerciseDefinitionRulesTests`, and `ExerciseModel(from:)`.
void main() {
  group(ExerciseDefinitionRules, () {
    test('the contribution is a percentage', () {
      for (final (value, valid) in [
        (-1, false),
        (0, true),
        (75, true),
        (100, true),
        (101, false),
      ]) {
        expect(
          ExerciseDefinitionRules.isValidContribution(value),
          valid,
          reason: '$value',
        );
      }
    });

    test('a bodyweight exercise cannot track a load', () {
      for (final metric in [
        TrackableExerciseMetric.weight,
        TrackableExerciseMetric.weightPerSide,
        TrackableExerciseMetric.weightPerSidePersistent,
      ]) {
        expect(
          ExerciseDefinitionRules.bodyweightConflict(
            isBodyweight: true,
            metrics: [TrackableExerciseMetric.reps, metric],
          ),
          isTrue,
        );
        expect(
          ExerciseDefinitionRules.bodyweightConflict(
            isBodyweight: false,
            metrics: [TrackableExerciseMetric.reps, metric],
          ),
          isFalse,
        );
      }
    });

    test('assistance and unloaded metrics are allowed', () {
      for (final metrics in [
        [
          TrackableExerciseMetric.repsPerSide,
          TrackableExerciseMetric.weightPerSideAssistance,
        ],
        [TrackableExerciseMetric.reps],
        [
          TrackableExerciseMetric.duration,
          TrackableExerciseMetric.distanceShort,
        ],
      ]) {
        expect(
          ExerciseDefinitionRules.bodyweightConflict(
            isBodyweight: true,
            metrics: metrics,
          ),
          isFalse,
        );
      }
    });

    test('every muscle appears in exactly one region', () {
      final upper = ExerciseDefinitionRules.upperMuscles.toSet();
      final lower = ExerciseDefinitionRules.lowerMuscles.toSet();
      expect(upper.intersection(lower), isEmpty);
      expect(upper.union(lower), Muscles.values.toSet());
      expect(upper, containsAll([Muscles.serratus, Muscles.chest]));
      expect(lower, containsAll([Muscles.quads, Muscles.tibialis]));
    });

    test('support and accessories are support; the rest resistance', () {
      expect(
        [
          for (final kind in EquipmentKind.values)
            if (ExerciseDefinitionRules.isSupport(kind)) kind,
        ],
        [EquipmentKind.supportEquipment, EquipmentKind.accessoryEquipment],
      );
    });

    test('alternate names are split and trimmed, blanks dropped', () {
      expect(
        ExerciseDefinitionRules.splitAlternateNames(
          'Barbell Bench, Flat Bench ,Chest Press',
        ),
        ['Barbell Bench', 'Flat Bench', 'Chest Press'],
      );
      expect(ExerciseDefinitionRules.splitAlternateNames(''), isEmpty);
      expect(ExerciseDefinitionRules.splitAlternateNames('Barbell Bench, '), [
        'Barbell Bench',
      ]);
    });
  });

  group(ExerciseDraft, () {
    const draft = ExerciseDraft(
      name: 'Bench Press',
      metricA: TrackableExerciseMetric.reps,
      metricB: TrackableExerciseMetric.weight,
      type: ExerciseType.compoundUpper,
      laterality: Laterality.bilateral,
      muscleGroups: {
        Muscles.chest: MuscleTargetType.primary,
        Muscles.triceps: MuscleTargetType.secondary,
      },
      variations: [
        VariationDraft(
          id: 'v1',
          resistance: [(EquipmentKind.loadableBar, 'barbell')],
          support: [(EquipmentKind.supportEquipment, 'flat_bench')],
        ),
      ],
      rangeOfMotion: 4,
      stability: 2,
      bodyweightContribution: 60,
      alternateNames: ['Flat Bench'],
      description: 'Press the bar off the chest.',
    );
    final now = DateTime.utc(2026, 10, 16);

    test('the stored exercise carries everything the flow collected', () {
      final stored = draft.toModel(id: 'e1', authorId: 'user-42', now: now);
      expect(stored.id, 'e1');
      expect(stored.authorId, 'user-42');
      expect(stored.isSystemExercise, isFalse);
      expect(stored.name, 'Bench Press');
      expect(stored.description, 'Press the bar off the chest.');
      expect(stored.type, ExerciseType.compoundUpper);
      expect(stored.laterality, Laterality.bilateral);
      expect(stored.muscleGroups, draft.muscleGroups);
      expect(stored.isBodyweight, isFalse);
      expect(stored.equipmentVariations.single.toFirestore(), {
        'id': 'v1',
        'resistance_equipment': [
          {'kind': 'loadableBar', 'id': 'barbell'},
        ],
        'support_equipment': [
          {'kind': 'supportEquipment', 'id': 'flat_bench'},
        ],
      });
      expect(stored.rangeOfMotion, 4);
      expect(stored.stability, 2);
      expect(stored.bodyWeightContribution, 60);
      expect(stored.alternateNames, ['Flat Bench']);
      expect(stored.dateCreated, now);
      expect(stored.dateModified, now);
      expect(
        [stored.clickCount, stored.bookmarkCount, stored.favouriteCount],
        [0, 0, 0],
      );
    });

    test('the metrics are stored in the order chosen, without a gap', () {
      expect(draft.toModel(id: 'e', authorId: 'u', now: now).trackableMetrics, [
        TrackableExerciseMetric.reps,
        TrackableExerciseMetric.weight,
      ]);
      const one = ExerciseDraft(
        name: 'Plank',
        metricA: TrackableExerciseMetric.duration,
      );
      expect(one.metrics, [TrackableExerciseMetric.duration]);
    });

    test('a duplicate copies the exercise into the flow', () {
      final stored = draft.toModel(id: 'e1', authorId: 'u', now: now);
      expect(ExerciseDraft.duplicating(stored), draft);
      final bare = ExerciseModel.fromFirestore(
        {...stored.toFirestore(), 'trackable_metrics': <String>[]}
          ..remove('description'),
      );
      final copy = ExerciseDraft.duplicating(bare);
      expect(copy.metrics, [TrackableExerciseMetric.reps]);
      expect(copy.description, '');
    });

    test('copyWith keeps what it is not given', () {
      expect(draft.copyWith(), draft);
      expect(draft.copyWith(stability: 5).stability, 5);
      expect(draft.variations.single.copyWith(), draft.variations.single);
    });
  });
}
