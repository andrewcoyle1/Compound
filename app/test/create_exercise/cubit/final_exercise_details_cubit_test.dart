import 'package:compound/create_exercise/create_exercise.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// Mirrors `FinalExerciseDetailsPresenterTests`; the footer is in the view
/// tests.
void main() {
  late AnalyticsRecorder analytics;

  /// A bodyweight exercise tracks reps only, since it cannot be loaded.
  ExerciseDraft draft({bool isBodyweight = false}) => ExerciseDraft(
    name: 'Bench Press',
    metricA: TrackableExerciseMetric.reps,
    metricB: isBodyweight ? null : TrackableExerciseMetric.weight,
    type: ExerciseType.compoundUpper,
    laterality: Laterality.bilateral,
    muscleGroups: const {Muscles.chest: MuscleTargetType.primary},
    isBodyweight: isBodyweight,
    variations: isBodyweight
        ? const []
        : const [
            VariationDraft(
              id: 'v1',
              resistance: [(EquipmentKind.loadableBar, 'barbell')],
            ),
          ],
    bodyweightContribution: isBodyweight
        ? ExerciseDefinitionRules.bodyweightContributionPreset
        : 0,
  );

  FinalExerciseDetailsCubit build(ExerciseDraft draft) {
    analytics = AnalyticsRecorder();
    final cubit = FinalExerciseDetailsCubit(draft: draft, analytics: analytics);
    addTearDown(cubit.close);
    return cubit;
  }

  test('everything handed in is handed on', () {
    expect(build(draft()).next, draft());
  });

  test('the numbers entered here reach the save step', () {
    final next =
        (build(draft(isBodyweight: true))
              ..rangeOfMotionChanged(4)
              ..stabilityChanged(2)
              ..contributionChanged('60')
              ..descriptionChanged('Press the bar off the chest.'))
            .next!;
    expect(next.rangeOfMotion, 4);
    expect(next.stability, 2);
    expect(next.bodyweightContribution, 60);
    expect(next.description, 'Press the bar off the chest.');
  });

  test('a loaded exercise keeps its bodyweight contribution', () {
    expect(
      (build(draft())..contributionChanged('85')).next!.bodyweightContribution,
      85,
    );
  });

  test('the contribution must be a percentage', () {
    for (final isBodyweight in [false, true]) {
      final cubit = build(draft(isBodyweight: isBodyweight))
        ..contributionChanged('140');
      expect(cubit.state.canContinue, isFalse);
      expect(cubit.next, isNull);
      cubit.contributionChanged('-1');
      expect(cubit.state.isContributionInRange, isFalse);
      cubit.contributionChanged('');
      expect(cubit.state.isContributionInRange, isFalse);
      cubit.contributionChanged('100');
      expect(cubit.state.canContinue, isTrue);
    }
  });

  test('a bodyweight exercise that tracks a load cannot continue', () {
    final loaded = build(
      const ExerciseDraft(
        name: 'Dip',
        metricA: TrackableExerciseMetric.reps,
        metricB: TrackableExerciseMetric.weight,
        isBodyweight: true,
      ),
    );
    expect(loaded.state.hasBodyweightConflict, isTrue);
    expect(loaded.state.canContinue, isFalse);
    expect(loaded.next, isNull);

    final assisted = build(
      const ExerciseDraft(
        name: 'Assisted Dip',
        metricA: TrackableExerciseMetric.reps,
        metricB: TrackableExerciseMetric.weightPerSideAssistance,
        isBodyweight: true,
      ),
    );
    expect(assisted.state.hasBodyweightConflict, isFalse);
    expect(assisted.state.canContinue, isTrue);
  });

  test('alternate names are split and trimmed', () {
    expect(
      (build(draft())
            ..alternateNamesChanged('Barbell Bench, Flat Bench ,Chest Press'))
          .next!
          .alternateNames,
      ['Barbell Bench', 'Flat Bench', 'Chest Press'],
    );
  });

  test('an untouched field carries no alternate names', () {
    expect(build(draft()).next!.alternateNames, isEmpty);
  });

  test('a trailing comma leaves no blank name', () {
    expect(
      (build(
        draft(),
      )..alternateNamesChanged('Barbell Bench, ')).next!.alternateNames,
      ['Barbell Bench'],
    );
  });

  test('alternate names stop at the limit', () {
    final cubit = build(draft())..alternateNamesChanged('a' * 400);
    expect(
      cubit.state.alternateNames,
      hasLength(ExerciseDefinitionRules.alternateNamesLimit),
    );
  });

  test('the contribution starts at zero or the bodyweight preset', () {
    expect(build(draft()).state.contribution, 0);
    expect(build(draft(isBodyweight: true)).state.contribution, 75);
  });

  test('appearing is tracked as a screen view', () {
    build(draft())
      ..appeared()
      ..disappeared();
    expect(analytics.names, [
      'FinalExerciseDetailsView_Appear',
      'FinalExerciseDetailsView_Disappear',
    ]);
  });

  test('a duplicate opens with its other names', () {
    final cubit = FinalExerciseDetailsCubit(
      draft: const ExerciseDraft(
        name: 'Row',
        metricA: TrackableExerciseMetric.reps,
        alternateNames: ['One-Arm Row', 'DB Row'],
      ),
      analytics: AnalyticsRecorder(),
    );
    addTearDown(cubit.close);
    expect(cubit.state.alternateNames, 'One-Arm Row, DB Row');
  });
}
