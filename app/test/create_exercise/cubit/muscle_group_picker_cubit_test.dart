import 'package:compound/create_exercise/create_exercise.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// Mirrors `MuscleGroupPickerPresenterTests`.
void main() {
  late AnalyticsRecorder analytics;
  const draft = ExerciseDraft(
    name: 'Bench Press',
    metricA: TrackableExerciseMetric.reps,
    metricB: TrackableExerciseMetric.weight,
    type: ExerciseType.compoundUpper,
    laterality: Laterality.bilateral,
  );

  MuscleGroupPickerCubit build() {
    analytics = AnalyticsRecorder();
    final cubit = MuscleGroupPickerCubit(draft: draft, analytics: analytics);
    addTearDown(cubit.close);
    return cubit;
  }

  test('pressing a muscle cycles primary, secondary and off', () {
    final cubit = build()..pressed(Muscles.chest);
    expect(cubit.state.selected[Muscles.chest], MuscleTargetType.primary);
    cubit.pressed(Muscles.chest);
    expect(cubit.state.selected[Muscles.chest], MuscleTargetType.secondary);
    cubit.pressed(Muscles.chest);
    expect(cubit.state.selected, isEmpty);
  });

  test('the counts split primary from secondary', () {
    final cubit = build()
      ..pressed(Muscles.chest)
      ..pressed(Muscles.triceps)
      ..pressed(Muscles.triceps)
      ..pressed(Muscles.frontDelts)
      ..pressed(Muscles.frontDelts);
    expect(cubit.state.primaryCount, 1);
    expect(cubit.state.secondaryCount, 2);
  });

  test('reset clears every selection', () {
    final cubit = build()
      ..pressed(Muscles.chest)
      ..pressed(Muscles.quads)
      ..reset();
    expect(cubit.state.selected, isEmpty);
  });

  test('the chosen muscles and everything before reach the equipment step', () {
    final cubit = build()
      ..pressed(Muscles.chest)
      ..pressed(Muscles.triceps)
      ..pressed(Muscles.triceps);
    expect(
      cubit.next,
      draft.copyWith(
        muscleGroups: {
          Muscles.chest: MuscleTargetType.primary,
          Muscles.triceps: MuscleTargetType.secondary,
        },
      ),
    );
  });

  test('the step can be skipped entirely', () {
    expect(build().next.muscleGroups, isEmpty);
  });

  test('appearing is tracked as a screen view', () {
    build()
      ..appeared()
      ..disappeared();
    expect(analytics.names, [
      'MuscleGroupPickerView_Appear',
      'MuscleGroupPickerView_Disappear',
    ]);
  });
}
