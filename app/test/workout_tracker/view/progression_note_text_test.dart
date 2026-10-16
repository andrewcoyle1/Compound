import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_rules/training_rules.dart' as r;

/// The progression note's words: ActiveWorkoutStateTests' reason cases and
/// ActiveWorkoutPiecesTests' plan summary cases.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final start = DateTime.utc(2026, 1, 12);

  group('progressionReason', () {
    String reason(r.ProgressionReason reason, [ExerciseWeightUnit? unit]) =>
        TrackerText.progressionReason(
          l10n,
          reason,
          unit ?? ExerciseWeightUnit.kilograms,
          locale: 'en',
        );

    test('says what changed and why', () {
      expect(
        reason(
          const r.ProgressionReason(
            rationale: r.Rationale.progressWeight,
            changeKg: 2.5,
            lastMinReps: 5,
          ),
        ),
        '+2.5 kg today. You hit 5 reps on every working set last time.',
      );
      expect(
        reason(
          const r.ProgressionReason(
            rationale: r.Rationale.addReps,
            addedReps: 1,
          ),
        ),
        '+1 rep today, at the same weight as last time.',
      );
      expect(
        reason(
          const r.ProgressionReason(
            rationale: r.Rationale.deload,
            changeKg: -10,
          ),
        ),
        '−10 kg today. Two sessions short of the reps, so the weight resets.',
      );
      expect(
        reason(
          const r.ProgressionReason(
            rationale: r.Rationale.progressWeight,
            changeKg: 2.267962,
          ),
          ExerciseWeightUnit.pounds,
        ),
        '+5 lb today.',
      );
    });
  });

  group('planSummary', () {
    WorkoutSetModel set(
      String id, {
      double? weight = 100,
      int? reps = 8,
      String kind = 'standard',
      String? parent,
      String? side,
      int? target,
      bool warmup = false,
      bool logged = false,
    }) => WorkoutSetModel(
      id: id,
      authorId: 'author-1',
      index: 1,
      reps: reps,
      weightKg: weight,
      sideRawValue: side,
      kindRawValue: kind,
      parentSetId: parent,
      targetReps: target,
      isWarmup: warmup,
      completedAt: logged ? start : null,
      dateCreated: start,
    );

    String? summary(List<WorkoutSetModel> sets) => TrackerText.planSummary(
      l10n,
      WorkoutExerciseModel(
        id: 'e1',
        authorId: 'author-1',
        templateId: 't1',
        name: 'Bench Press',
        trackingMode: TrackingMode.weightReps,
        index: 1,
        sets: sets,
      ),
      ExerciseWeightUnit.kilograms,
      locale: 'en',
    );

    // Set 3 of the mock-up: 100 × 8, then 80 and 64 to failure.
    List<WorkoutSetModel> dropSet({bool logged = true}) => [
      set('s1', logged: logged),
      set('s2', logged: logged),
      set('s3', kind: 'drop'),
      set('d1', weight: 80, reps: null, kind: 'drop', parent: 's3'),
      set('d2', weight: 64, reps: null, kind: 'drop', parent: 's3'),
      set('s4', kind: 'amrap', target: 8),
    ];

    test('the plan reads as the mock-up', () {
      expect(
        summary(dropSet(logged: false)),
        'Set 3 is a drop set from your plan: 100 × 8, then 80 and 64 to '
        'failure, no rest between. Set 4 is to failure, target 8+.',
      );
    });

    test('drops with reps, and mini-sets', () {
      expect(
        summary([
          set('s1', kind: 'drop'),
          set('d1', weight: 80, reps: 10, kind: 'drop', parent: 's1'),
          set('s2', kind: 'myo'),
          set('m1', reps: 5, parent: 's2'),
          set('m2', reps: 5, parent: 's2'),
        ]),
        'Set 1 is a drop set from your plan: 100 × 8, then 80 × 10, no rest '
        'between. Set 2 is Myo-reps from your plan: 100 × 8, then 2 '
        'mini-sets, a short breath between.',
      );
      expect(
        summary([
          set('s1', kind: 'drop'),
          set('d1', weight: 80, reps: null, kind: 'drop', parent: 's1'),
          set('d2', weight: 60, reps: null, kind: 'drop', parent: 's1'),
          set('d3', weight: 40, reps: null, kind: 'drop', parent: 's1'),
          set('s2', weight: null, reps: null, kind: 'restPause'),
          set('m1', reps: 5, parent: 's2'),
        ]),
        'Set 1 is a drop set from your plan: 100 × 8, then 80, 60, and 40 to '
        'failure, no rest between. Set 2 is Rest-pause from your plan: '
        '—, then 1 mini-set, a short breath between.',
      );
    });

    test('a pair is told once', () {
      expect(
        summary([
          set('l1', side: 'left'),
          set('r1', side: 'right'),
          set('l2', kind: 'amrap', side: 'left', target: 10),
          set('r2', kind: 'amrap', side: 'right', target: 10),
        ]),
        'Set 2 is to failure, target 10+.',
      );
    });

    test('no plan, or one already begun, says nothing', () {
      expect(summary([set('s1'), set('s2')]), isNull);
      // An AMRAP set with no target from the plan is no plan.
      expect(summary([set('s1', kind: 'amrap')]), isNull);
      // Once a working set is logged the plan is under way.
      expect(summary(dropSet()), isNull);
      // A warm-up logged is not.
      expect(
        summary([
          set('w1', warmup: true, logged: true),
          set('s1', kind: 'amrap', target: 8),
        ]),
        'Set 1 is to failure, target 8+.',
      );
    });

    test('reps alone read as reps', () {
      expect(
        summary([
          set('s1', weight: null, kind: 'drop'),
          set('d1', weight: null, reps: null, kind: 'drop', parent: 's1'),
        ]),
        'Set 1 is a drop set from your plan: 8 reps, then — to failure, no '
        'rest between.',
      );
    });
  });
}
