import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_editor/workout_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../../helpers/helpers.dart';

/// Mirrors `SetTargetPlanSummaryTests`, `MicrocycleVariationSummaryTests`
/// and `DefineWorkoutRulesTests`' plan line.
void main() {
  final text = EditorText(
    lookupAppLocalizations(const Locale('en')),
    locale: 'en',
  );
  const settings = WorkoutSettings(authorId: 'user-1');

  SetTarget target({
    int setNumber = 1,
    int? minReps,
    int? maxReps,
    SetTargetSetType setType = SetTargetSetType.standard,
    int? dropCount,
    int? dropStepPercent,
    int? dropReps,
    int? miniSetCount,
    int? amrapTargetReps,
    int? partialReps,
    int? holdSeconds,
  }) => SetTarget(
    id: 't',
    setNumber: setNumber,
    minReps: minReps,
    maxReps: maxReps,
    setType: setType,
    dropCount: dropCount,
    dropStepPercent: dropStepPercent,
    dropReps: dropReps,
    miniSetCount: miniSetCount,
    amrapTargetReps: amrapTargetReps,
    partialReps: partialReps,
    holdSeconds: holdSeconds,
  );

  group('the set plan line', () {
    test('a standard set shows nothing extra', () {
      final standard = target(minReps: 8, maxReps: 8);
      expect(text.summary(standard, settings), isNull);
      expect(text.chip(standard), isNull);
    });

    test('a drop set to failure', () {
      final drop = target(
        setNumber: 3,
        minReps: 8,
        maxReps: 8,
        setType: SetTargetSetType.drop,
        dropCount: 2,
      );
      expect(text.summary(drop, settings), '8 reps, then −20% ×2 to failure');
      expect(text.chip(drop), 'Drop set');
    });

    test('a drop set with reps on each drop, its own step and a range', () {
      expect(
        text.summary(
          target(
            minReps: 8,
            maxReps: 12,
            setType: SetTargetSetType.drop,
            dropCount: 1,
            dropStepPercent: 30,
            dropReps: 6,
          ),
          settings,
        ),
        '8–12 reps, then −30% ×1, 6 reps each',
      );
    });

    test('a drop set with no reps planned starts at the drops', () {
      expect(
        text.summary(
          target(setType: SetTargetSetType.drop, dropCount: 2),
          settings,
        ),
        '−20% ×2 to failure',
      );
      expect(
        text.summary(
          target(minReps: 8, maxReps: 8, setType: SetTargetSetType.drop),
          settings,
        ),
        '8 reps',
      );
    });

    test('an AMRAP set names its target', () {
      final amrap = target(
        setNumber: 4,
        setType: SetTargetSetType.amrap,
        amrapTargetReps: 8,
      );
      expect(text.summary(amrap, settings), 'As many as possible, target 8');
      expect(text.chip(amrap), 'Failure 8+');
      expect(
        text.summary(target(setType: SetTargetSetType.amrap), settings),
        'As many as possible',
      );
      expect(text.chip(target(setType: SetTargetSetType.amrap)), 'Failure');
    });

    test('a legacy failure set reads as AMRAP', () {
      final failure = target(
        setType: SetTargetSetType.failure,
        amrapTargetReps: 10,
      );
      expect(text.kindTitle(SetTargetSetType.failure), 'Failure');
      expect(text.chip(failure), 'Failure 10+');
      expect(text.summary(failure, settings), 'As many as possible, target 10');
    });

    test("mini-sets read their kind's own rest", () {
      const rests = WorkoutSettings(
        authorId: 'user-1',
        intraSetRestPauseSeconds: 30,
      );
      expect(
        text.summary(
          target(setType: SetTargetSetType.myo, miniSetCount: 3),
          rests,
        ),
        '3 mini-sets, 15 s breath',
      );
      expect(
        text.summary(
          target(setType: SetTargetSetType.restPause, miniSetCount: 1),
          rests,
        ),
        '1 mini-set, 30 s breath',
      );
      expect(
        text.summary(
          target(setType: SetTargetSetType.cluster, miniSetCount: 4),
          rests,
        ),
        '4 mini-sets, 15 s breath',
      );
      expect(EditorText.intraSetRest(settings, SetTargetSetType.restPause), 20);
      expect(
        EditorText.intraSetRest(
          const WorkoutSettings(authorId: 'u', intraSetRestClusterSeconds: 9),
          SetTargetSetType.cluster,
        ),
        9,
      );
    });

    test('a kind with no pieces planned reads as its reps', () {
      expect(
        text.summary(
          target(minReps: 10, maxReps: 10, setType: SetTargetSetType.myo),
          settings,
        ),
        '10 reps',
      );
    });

    test('the picker offers every kind but the legacy one', () {
      expect(
        [for (final kind in WorkoutEditorRules.kinds) text.kindTitle(kind)],
        [
          'Standard',
          'Failure',
          'Myo-reps',
          'Rest-pause',
          'Cluster',
          'Drop set',
          'Lengthened partials',
          'Loaded stretch',
          'Static hold',
        ],
      );
    });

    test('partials to failure or for a count', () {
      final toFailure = target(
        minReps: 8,
        maxReps: 8,
        setType: SetTargetSetType.partials,
      );
      expect(
        text.summary(toFailure, settings),
        '8 reps, then partials to failure',
      );
      expect(
        text.summary(
          target(
            minReps: 8,
            maxReps: 8,
            setType: SetTargetSetType.partials,
            partialReps: 5,
          ),
          settings,
        ),
        '8 reps, then 5 partials',
      );
      expect(text.chip(toFailure), 'Lengthened partials');
    });

    test('a stretch and a hold name their time', () {
      final stretch = target(
        minReps: 8,
        maxReps: 12,
        setType: SetTargetSetType.stretch,
        holdSeconds: 30,
      );
      final hold = target(
        minReps: 8,
        maxReps: 8,
        setType: SetTargetSetType.hold,
        holdSeconds: 30,
      );
      expect(text.summary(stretch, settings), '8–12 reps, then a 30 s stretch');
      expect(text.summary(hold, settings), '8 reps, then a 30 s hold');
      expect(text.chip(stretch), 'Loaded stretch');
      expect(text.chip(hold), 'Static hold');
      expect(
        text.summary(
          target(minReps: 8, maxReps: 8, setType: SetTargetSetType.hold),
          settings,
        ),
        '8 reps',
      );
      expect(
        text.summary(
          target(setType: SetTargetSetType.stretch, holdSeconds: 20),
          settings,
        ),
        'a 20 s stretch',
      );
      expect(
        text.summary(target(setType: SetTargetSetType.stretch), settings),
        isNull,
      );
    });

    test('a range typed upside down reads the right way up', () {
      expect(
        text.summary(
          target(
            minReps: 12,
            maxReps: 8,
            setType: SetTargetSetType.hold,
            holdSeconds: 15,
          ),
          settings,
        ),
        '8–12 reps, then a 15 s hold',
      );
      expect(
        text.summary(
          target(maxReps: 1, setType: SetTargetSetType.hold, holdSeconds: 15),
          settings,
        ),
        '1 rep, then a 15 s hold',
      );
    });
  });

  group('weekly variation', () {
    List<SetTarget> sets(int count) => [
      for (var i = 1; i <= count; i++) SetTarget(id: 's$i', setNumber: i),
    ];

    test('nothing varies without overrides', () {
      expect(text.variationSummary(sets(2), const []), 'Same every week');
    });

    test('consecutive overrides bound each other and the last runs on', () {
      expect(
        text.variationSummary(sets(2), [
          MicrocycleSetTargets(fromMicrocycle: 9, setTargets: sets(4)),
          MicrocycleSetTargets(fromMicrocycle: 2, setTargets: sets(3)),
        ]),
        'Week 1: 2 sets · Weeks 2–8: 3 sets · From week 9: 4 sets',
      );
    });

    test('a base of several weeks and a one-week override read as ranges', () {
      expect(
        text.variationSummary(sets(3), [
          MicrocycleSetTargets(fromMicrocycle: 5, setTargets: sets(1)),
          MicrocycleSetTargets(fromMicrocycle: 6, setTargets: sets(3)),
        ]),
        'Weeks 1–4: 3 sets · Week 5: 1 set · From week 6: 3 sets',
      );
    });

    test('an override from week 1 replaces the base', () {
      expect(
        text.variationSummary(sets(3), [
          MicrocycleSetTargets(fromMicrocycle: 1, setTargets: sets(2)),
        ]),
        'From week 1: 2 sets',
      );
    });
  });

  group('the plan line under an exercise', () {
    final exercise = fixtureSlot(fixtureLibraryExercise('bench'));

    test('names only the parts set', () {
      expect(text.planSummary(exercise), isNull);
      expect(
        text.planSummary(
          exercise.copyWith(
            warmupSetCount: () => 3,
            restSeconds: () => 120,
            substituteExerciseIds: ['x', 'y'],
            notes: () => 'Pause at the bottom',
            setTargetsByMicrocycle: const [
              MicrocycleSetTargets(fromMicrocycle: 2, setTargets: []),
            ],
          ),
        ),
        '3 warm-ups · 2:00 rest · 2 alternatives · notes · varies by week',
      );
      expect(
        text.planSummary(
          exercise.copyWith(
            warmupSetCount: () => 1,
            substituteExerciseIds: ['x'],
            notes: () => '   ',
            linkUrl: () => 'https://example.com',
          ),
        ),
        '1 warm-up · 1 alternative · link',
      );
    });

    test('no warm-ups is a plan too, and no rest is none', () {
      expect(
        text.planSummary(
          exercise.copyWith(warmupSetCount: () => 0, restSeconds: () => 0),
        ),
        '0 warm-ups',
      );
    });
  });

  test('titles', () {
    expect(text.restTitle(null), 'Automatic');
    expect(text.restTitle(90), '1:30');
    expect(text.warmupTitle(null), 'Automatic');
    expect(text.warmupTitle(3), '3');
    expect(text.dropStepTitle(25), '−25%');
    expect(EditorText.rirText(null), AppFormat.placeholder);
    expect(EditorText.rirText(2), '2');
    expect(EditorText.rirText(6), '6+');
    expect(text.weeksTitle(3, 3), 'Week 3');
  });
}
