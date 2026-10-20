import 'package:compound/workout_editor/workout_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../../helpers/helpers.dart';

/// Mirrors `SetTargetPlanPresenterTests`, `WorkoutBuildUnsavedChangesTests`
/// and `WorkoutBuildSetTargetPresenterTests`.
void main() {
  late AnalyticsRecorder analytics;
  late int ids;
  final own = fixtureLibraryExercise('bench');
  final library = [
    own,
    fixtureLibraryExercise('row'),
    fixtureLibraryExercise('dip'),
    fixtureLibraryExercise('fly'),
  ];

  SetTargetCubit build({
    bool plansSets = true,
    List<SetTarget> targets = const [
      SetTarget(id: 's1', setNumber: 1, minReps: 8, maxReps: 8),
    ],
    SetTargetScope scope = const TemplateScope(),
    String? link,
  }) {
    analytics = AnalyticsRecorder();
    final cubit = SetTargetCubit(
      exercise: fixtureSlot(own)
          .copyWith(setTargets: targets, linkUrl: () => link),
      scope: scope,
      settings: WorkoutSettings(authorId: 'u', setPlanning: plansSets),
      library: library,
      analytics: analytics,
      newId: () => 'id-${ids++}',
    );
    addTearDown(cubit.close);
    return cubit;
  }

  /// What [cubit] keeps on Save; null when it refused.
  WorkoutTemplateExercise? saveOf(SetTargetCubit cubit) =>
      (cubit..save()).state.saved;

  setUp(() => ids = 0);

  group('the targets', () {
    test('appearing and leaving are tracked separately', () async {
      final cubit = build();
      expect(analytics.names, ['SetTargetView_Appear']);
      await cubit.close();
      expect(analytics.names, [
        'SetTargetView_Appear',
        'SetTargetView_Disappear',
      ]);
    });

    test('closing after an edit asks first', () {
      final cubit = build();
      expect(cubit.state.hasUnsavedChanges, isFalse);
      cubit.addSet();
      expect(cubit.state.hasUnsavedChanges, isTrue);
      expect(cubit.state.exercise.setTargets.last.minReps, 8);
    });

    test('a minimum above the maximum is swapped on save', () {
      final cubit = build();
      final set = cubit.state.exercise.setTargets.single;
      cubit.setChanged(set.copyWith(minReps: () => 12, maxReps: () => 8));
      final saved = saveOf(cubit)!.setTargets.single;
      expect((saved.minReps, saved.maxReps), (8, 12));
    });

    test('deleting a set renumbers the rest', () {
      final cubit = build()
        ..addSet()
        ..addSet()
        ..deleteSet('s1');
      expect(
        [for (final t in cubit.state.exercise.setTargets) t.setNumber],
        [1, 2],
      );
    });

    test('the editor follows the set plan switch', () {
      expect(build().state.plansSets, isTrue);
      expect(build(plansSets: false).state.plansSets, isFalse);
    });

    test('rest timers are set for the exercise', () {
      final cubit = build()..restTimersChanged(on: true);
      expect(saveOf(cubit)!.setRestTimers, isTrue);
    });
  });

  group("the exercise's plan", () {
    for (final count in [null, 0, 4]) {
      test('warm-ups $count are saved', () {
        final cubit = build()..warmupsChanged(count);
        expect(saveOf(cubit)!.warmupSetCount, count);
      });
    }

    test('rest is automatic or a chosen time, and saved', () {
      final cubit = build()..restChanged(90);
      expect(cubit.state.hasUnsavedChanges, isTrue);
      expect(saveOf(cubit)!.restSeconds, 90);
    });

    test('notes are trimmed on save and blank notes are none', () {
      expect(
        saveOf(build()..notesChanged('  Pause at the bottom \n'))!.notes,
        'Pause at the bottom',
      );
      expect(saveOf(build()..notesChanged('   '))!.notes, isNull);
      expect(saveOf(build()..notesChanged(''))!.notes, isNull);
    });

    test('a web address is saved as the link', () {
      final cubit = build()..linkChanged(' https://youtu.be/abc ');
      expect(cubit.state.linkIsValid, isTrue);
      expect(saveOf(cubit)!.linkUrl, 'https://youtu.be/abc');
      expect(cubit.state.showsLinkError, isFalse);
    });

    test('anything else is refused with an error and nothing saved', () {
      final cubit = build()..linkChanged('youtube.com/abc');
      expect(cubit.state.hasUnsavedChanges, isTrue);
      expect(cubit.state.showsLinkError, isFalse);
      cubit.linkSubmitted();
      expect(cubit.state.showsLinkError, isTrue);
      expect(saveOf(cubit), isNull);
      expect(cubit.state.exercise.linkUrl, isNull);
      cubit.linkChanged('https://youtube.com/abc');
      expect(cubit.state.showsLinkError, isFalse);
    });

    test('clearing the link removes it', () {
      final cubit = build(link: 'https://example.com');
      expect(cubit.state.linkText, 'https://example.com');
      cubit.linkChanged('');
      expect(saveOf(cubit)!.linkUrl, isNull);
    });

    test('substitutions are added, never the exercise itself, and removed', () {
      final cubit = build()..substitutionsPicked([library[1], own, library[2]]);
      expect([for (final e in cubit.state.substitutes) e.id], ['row', 'dip']);
      cubit
        ..substitutionsPicked([library[1]])
        ..substitutionRemoved('row');
      expect(saveOf(cubit)!.substituteExerciseIds, ['dip']);
    });

    test('a substitution the library does not know is not listed', () {
      final cubit = build()
        ..substitutionsPicked([fixtureLibraryExercise('gone')]);
      expect(cubit.state.substitutes, isEmpty);
    });

    test('the plan is offered for a template only; a week edits targets', () {
      final template = build();
      expect(template.state.showsPlan, isTrue);
      expect(template.state.showsRestTimers, isTrue);
      final week = build(scope: const WeekScope(3));
      expect(week.state.showsPlan, isFalse);
      expect(week.state.showsRestTimers, isFalse);
      expect(const WeekScope(3), const WeekScope(3));
      expect(const TemplateScope().props, isEmpty);
      // A session's exercise, from the tracker: targets only.
      final session = build(scope: const SessionScope());
      expect(session.state.showsPlan, isFalse);
      expect(session.state.showsRestTimers, isFalse);
    });

    test('weekly variations are kept', () {
      final cubit = build()
        ..variationsChanged(const [
          MicrocycleSetTargets(
            fromMicrocycle: 2,
            setTargets: [
              SetTarget(id: 'a', setNumber: 1),
              SetTarget(id: 'b', setNumber: 2),
            ],
          ),
        ]);
      expect(
        [
          for (final o in saveOf(cubit)!.setTargetsByMicrocycle)
            o.fromMicrocycle,
        ],
        [2],
      );
    });
  });

  group("a set's plan", () {
    SetPlanDetailCubit detail(SetTargetCubit editor, [int index = 0]) {
      final cubit = SetPlanDetailCubit(
        target: editor.state.exercise.setTargets[index],
        onChange: editor.setChanged,
        analytics: analytics,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    SetTarget saved(SetTargetCubit editor) => saveOf(editor)!.setTargets.single;

    test('the sheet tracks its appearance', () {
      final editor = build();
      detail(editor);
      expect(analytics.names, contains('SetPlanDetailView_Appear'));
    });

    test('choosing drop set starts with two drops and saves each field', () {
      final editor = build();
      final sheet = detail(editor)..kindChanged(SetTargetSetType.drop);
      expect(sheet.state.dropCount, 2);
      expect(editor.state.hasUnsavedChanges, isTrue);
      sheet
        ..dropCountChanged(3)
        ..dropRepsChanged(6)
        ..dropStepPressed(30)
        ..dropStepPressed(30);
      final target = saved(editor);
      expect(target.setType, SetTargetSetType.drop);
      expect(target.dropCount, 3);
      expect(target.dropStepPercent, 30);
      expect(target.dropReps, 6);
      expect((target.minReps, target.maxReps), (8, 8));
    });

    test('clearing the drop reps goes back to failure', () {
      final editor = build(
        targets: const [
          SetTarget(
            id: 's1',
            setNumber: 1,
            setType: SetTargetSetType.drop,
            dropCount: 2,
            dropReps: 6,
          ),
        ],
      );
      detail(editor).dropRepsChanged(null);
      expect(editor.state.exercise.setTargets.single.dropReps, isNull);
    });

    for (final kind in [
      SetTargetSetType.myo,
      SetTargetSetType.restPause,
      SetTargetSetType.cluster,
    ]) {
      test('mini-sets are saved for $kind', () {
        final editor = build();
        final sheet = detail(editor)..kindChanged(kind);
        expect(sheet.state.miniSetCount, 3);
        sheet.miniSetCountChanged(5);
        expect(saved(editor).setType, kind);
        expect(saved(editor).miniSetCount, 5);
      });
    }

    test("an AMRAP target starts from the set's reps and is saved", () {
      final editor = build();
      final sheet = detail(editor)..kindChanged(SetTargetSetType.amrap);
      expect(sheet.state.amrapTargetReps, 8);
      sheet.amrapTargetChanged(10);
      expect(saved(editor).setType, SetTargetSetType.amrap);
      expect(saved(editor).amrapTargetReps, 10);
    });

    test('partials start to failure and save their reps', () {
      final editor = build();
      final sheet = detail(editor)..kindChanged(SetTargetSetType.partials);
      expect(sheet.state.partialReps, isNull);
      sheet.partialRepsChanged(5);
      expect(saved(editor).partialReps, 5);
    });

    for (final kind in [SetTargetSetType.stretch, SetTargetSetType.hold]) {
      test('a $kind starts at 30 seconds and saves its time', () {
        final editor = build();
        final sheet = detail(editor)..kindChanged(kind);
        expect(sheet.state.holdSeconds, 30);
        sheet.holdSecondsChanged(45);
        expect(saved(editor).setType, kind);
        expect(saved(editor).holdSeconds, 45);
      });
    }

    test('a typed target that is not a count is no target', () {
      final editor = build(
        targets: const [
          SetTarget(
            id: 's1',
            setNumber: 1,
            setType: SetTargetSetType.amrap,
            amrapTargetReps: 8,
          ),
        ],
      );
      final sheet = detail(editor)..amrapTargetChanged(0);
      expect(sheet.state.amrapTargetReps, isNull);
      sheet.amrapTargetChanged(9.6);
      expect(sheet.state.amrapTargetReps, 10);
      sheet.amrapTargetChanged(double.infinity);
      expect(sheet.state.amrapTargetReps, isNull);
    });

    test('a legacy failure set shows as AMRAP and is written so on edit', () {
      final editor = build(
        targets: const [
          SetTarget(id: 's1', setNumber: 1, setType: SetTargetSetType.failure),
        ],
      );
      final sheet = detail(editor);
      expect(
        WorkoutEditorRules.shownKind(sheet.state.setType),
        SetTargetSetType.amrap,
      );
      expect(editor.state.hasUnsavedChanges, isFalse);
      sheet.amrapTargetChanged(8);
      expect(
        editor.state.exercise.setTargets.single.setType,
        SetTargetSetType.amrap,
      );
    });

    test('picking the kind already chosen changes nothing', () {
      final editor = build();
      detail(editor).kindChanged(SetTargetSetType.standard);
      expect(editor.state.hasUnsavedChanges, isFalse);
    });
  });
}
