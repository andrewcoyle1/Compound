import 'package:compound/create_exercise/create_exercise.dart';
import 'package:compound/training_library/logic/exercise_filters.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

const EquipmentKey _barbell = (EquipmentKind.loadableBar, 'barbell');
const EquipmentKey _dumbbell = (EquipmentKind.freeWeight, 'dumbbell');
const EquipmentKey _bench = (EquipmentKind.supportEquipment, 'flat_bench');

/// Mirrors `ExerciseEquipmentPresenterTests` and
/// `EquipmentPickerPresenterTests`.
void main() {
  late AnalyticsRecorder analytics;
  const draft = ExerciseDraft(
    name: 'Bench Press',
    metricA: TrackableExerciseMetric.reps,
    metricB: TrackableExerciseMetric.weight,
    type: ExerciseType.compoundUpper,
    laterality: Laterality.bilateral,
    muscleGroups: {Muscles.chest: MuscleTargetType.primary},
  );

  group(ExerciseEquipmentCubit, () {
    ExerciseEquipmentCubit build() {
      analytics = AnalyticsRecorder();
      var id = 0;
      final cubit = ExerciseEquipmentCubit(
        draft: draft,
        analytics: analytics,
        newId: () => 'v${++id}',
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('continuing needs resistance or the bodyweight toggle', () {
      expect(build().state.canContinue, isFalse);
      expect(
        (build()..supportChanged('v1', [_bench])).state.canContinue,
        isFalse,
      );
      expect(
        (build()..bodyweightChanged(isBodyweight: true)).state.canContinue,
        isTrue,
      );
    });

    test('a later variation with resistance is enough', () {
      final cubit = build()
        ..variationAdded()
        ..resistanceChanged('v2', [_barbell]);
      expect(cubit.state.canContinue, isTrue);
    });

    test('variations are added with their own ids', () {
      final cubit = build()..variationAdded();
      expect([for (final v in cubit.state.variations) v.id], ['v1', 'v2']);
    });

    test('deleting a variation leaves the others alone', () {
      final cubit = build()
        ..resistanceChanged('v1', [_barbell])
        ..variationAdded()
        ..variationDeleted('v2');
      expect(cubit.state.variations, [
        const VariationDraft(id: 'v1', resistance: [_barbell]),
      ]);
    });

    test('the last variation cannot be deleted', () {
      expect((build()..variationDeleted('v1')).state.variations, hasLength(1));
    });

    test('the picker writes into the variation that was tapped', () {
      final cubit = build()
        ..variationAdded()
        ..resistanceChanged('v2', [_dumbbell]);
      expect(cubit.state.variations[0].resistance, isEmpty);
      expect(cubit.state.variations[1].resistance, [_dumbbell]);
    });

    test('an unknown variation changes nothing', () {
      final cubit = build();
      final before = cubit.state;
      cubit
        ..resistanceChanged('gone', [_barbell])
        ..supportChanged('gone', [_bench]);
      expect(cubit.state, before);
    });

    test('the variations and everything before reach the final step', () {
      final next =
          (build()
                ..resistanceChanged('v1', [_barbell])
                ..supportChanged('v1', [_bench]))
              .next;
      expect(
        next,
        draft.copyWith(
          variations: [
            const VariationDraft(
              id: 'v1',
              resistance: [_barbell],
              support: [_bench],
            ),
          ],
        ),
      );
      expect(next.bodyweightContribution, 0);
    });

    test('the bodyweight flag reaches the final step with its variations', () {
      final next =
          (build()
                ..resistanceChanged('v1', [_barbell])
                ..bodyweightChanged(isBodyweight: true))
              .next;
      expect(next.isBodyweight, isTrue);
      expect(
        [for (final v in next.variations) v.resistance],
        [
          [_barbell],
        ],
      );
      expect(
        next.bodyweightContribution,
        ExerciseDefinitionRules.bodyweightContributionPreset,
      );
    });

    test('an empty variation is dropped', () {
      final next =
          (build()
                ..resistanceChanged('v1', [_barbell])
                ..variationAdded())
              .next;
      expect(next.variations, hasLength(1));
    });

    test('backing out and in again keeps the variations', () {
      final next = (build()..resistanceChanged('v1', [_barbell])).next;
      final again = ExerciseEquipmentCubit(draft: next, analytics: analytics);
      addTearDown(again.close);
      expect(again.state.variations, next.variations);
    });

    test('appearing is tracked as a screen view', () {
      build()
        ..appeared()
        ..disappeared();
      expect(analytics.names, [
        'ExerciseEquipmentView_Appear',
        'ExerciseEquipmentView_Disappear',
      ]);
    });
  });

  group(EquipmentPickerCubit, () {
    EquipmentPickerCubit build() {
      analytics = AnalyticsRecorder();
      final cubit = EquipmentPickerCubit(
        chosen: const [],
        analytics: analytics,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('pressing an item selects it and pressing it again deselects it', () {
      final cubit = build()..toggled(_barbell);
      expect(cubit.state, [_barbell]);
      cubit.toggled(_barbell);
      expect(cubit.state, isEmpty);
    });

    test('several items can be held at once', () {
      final cubit = build()
        ..toggled(_barbell)
        ..toggled(_dumbbell)
        ..toggled(_barbell);
      expect(cubit.state, [_dumbbell]);
    });

    test('appearing is tracked as a screen view', () {
      build()
        ..appeared()
        ..disappeared();
      expect(analytics.names, [
        'EquipmentPickerView_Appear',
        'EquipmentPickerView_Disappear',
      ]);
    });
  });
}
