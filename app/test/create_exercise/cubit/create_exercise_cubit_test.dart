import 'package:bloc_test/bloc_test.dart';
import 'package:compound/create_exercise/create_exercise.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// Mirrors `CreateExercisePresenterTests`.
void main() {
  late AnalyticsRecorder analytics;

  CreateExerciseCubit build() {
    analytics = AnalyticsRecorder();
    final cubit = CreateExerciseCubit(analytics: analytics);
    addTearDown(cubit.close);
    return cubit;
  }

  /// Filled in the way a user leaves it, the name padded as a keyboard
  /// leaves it.
  CreateExerciseCubit filled() => build()
    ..nameChanged('  Bench Press  ')
    ..metricAChanged(TrackableExerciseMetric.reps)
    ..metricBChanged(TrackableExerciseMetric.weight)
    ..typeChanged(ExerciseType.compoundUpper)
    ..lateralityChanged(Laterality.bilateral);

  test('closing after typing asks before discarding', () {
    expect((build()..nameChanged('   ')).state.hasUnsavedChanges, isFalse);
    expect(
      (build()..lateralityChanged(Laterality.unilateral))
          .state
          .hasUnsavedChanges,
      isTrue,
    );
  });

  test('a name and a metric are both required', () {
    expect(
      (build()
            ..nameChanged('   ')
            ..metricAChanged(TrackableExerciseMetric.reps))
          .state
          .canContinue,
      isFalse,
    );
    expect((build()..nameChanged('Bench Press')).state.canContinue, isFalse);
  });

  test('the second metric alone is enough to continue', () {
    expect(
      (build()
            ..nameChanged('Bench Press')
            ..metricBChanged(TrackableExerciseMetric.weight))
          .state
          .canContinue,
      isTrue,
    );
  });

  test('nothing opens until the gate is passed', () {
    expect(
      (build()..metricAChanged(TrackableExerciseMetric.reps)).continued(),
      isNull,
    );
    expect((build()..nameChanged('Bench Press')).continued(), isNull);
  });

  test('filling only the second metric promotes it to the first', () {
    final cubit = build()
      ..nameChanged('Plank')
      ..metricBChanged(TrackableExerciseMetric.duration);
    final draft = cubit.continued()!;
    expect(cubit.state.metricA, TrackableExerciseMetric.duration);
    expect(cubit.state.metricB, isNull);
    expect(draft.metricA, TrackableExerciseMetric.duration);
    expect(draft.metricB, isNull);
  });

  test('the typed fields reach the muscle group step', () {
    expect(
      filled().continued(),
      const ExerciseDraft(
        name: 'Bench Press',
        metricA: TrackableExerciseMetric.reps,
        metricB: TrackableExerciseMetric.weight,
        type: ExerciseType.compoundUpper,
        laterality: Laterality.bilateral,
      ),
    );
  });

  test('the optional details are carried as unset', () {
    final draft =
        (build()
              ..nameChanged('Bench Press')
              ..metricAChanged(TrackableExerciseMetric.reps))
            .continued()!;
    expect(draft.type, isNull);
    expect(draft.laterality, isNull);
  });

  test('a field can be set back to none', () {
    final cubit = filled()
      ..typeChanged(null)
      ..lateralityChanged(null)
      ..metricBChanged(null);
    expect(cubit.state.type, isNull);
    expect(cubit.state.laterality, isNull);
    expect(cubit.state.metricB, isNull);
  });

  blocTest<CreateExerciseCubit, CreateExerciseState>(
    'appearing is tracked as a screen view',
    build: build,
    act: (cubit) => cubit
      ..appeared()
      ..disappeared(),
    verify: (_) => expect(analytics.names, [
      'CreateExerciseView_Appear',
      'CreateExerciseView_Disappear',
    ]),
  );

  test('Edit Duplicate opens on a copy, carried to the next step', () {
    const copy = ExerciseDraft(
      name: 'Row',
      metricA: TrackableExerciseMetric.weight,
      metricB: TrackableExerciseMetric.repsPerSide,
      type: ExerciseType.compoundUpper,
      laterality: Laterality.unilateral,
      muscleGroups: {Muscles.lats: MuscleTargetType.primary},
      isBodyweight: true,
      variations: [VariationDraft(id: 'v1')],
      rangeOfMotion: 3,
      stability: 2,
      bodyweightContribution: 10,
      alternateNames: ['One-Arm Row'],
      description: 'Brace.',
    );
    analytics = AnalyticsRecorder();
    final cubit = CreateExerciseCubit(analytics: analytics, prefill: copy);
    addTearDown(cubit.close);
    expect(cubit.state.name, 'Row');
    expect(cubit.state.hasUnsavedChanges, isTrue);
    expect(cubit.continued(), copy);
  });
}
