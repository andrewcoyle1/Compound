import 'package:compound/workout_editor/workout_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../../helpers/helpers.dart';

/// Mirrors `DefineWorkoutPresenterTests`, `CreateWorkoutFlowPresenterTests`'
/// define and picker steps, and `WorkoutBuildUnsavedChangesTests`' reorder.
void main() {
  late List<WorkoutTemplateExercise> box;
  late AnalyticsRecorder analytics;
  late int ids;

  DefineWorkoutCubit build(List<WorkoutTemplateExercise> exercises) {
    box = exercises;
    analytics = AnalyticsRecorder();
    final cubit = DefineWorkoutCubit(
      read: () => box,
      write: (value) => box = value,
      analytics: analytics,
      newId: () => 'id-${ids++}',
    );
    addTearDown(cubit.close);
    return cubit;
  }

  /// Exercises named by id, with the group each is in.
  List<WorkoutTemplateExercise> list(List<(String, String?)> entries) => [
    for (final (id, group) in entries)
      fixtureSlot(
        fixtureLibraryExercise('bench'),
        id: id,
        supersetGroupId: group,
      ),
  ];

  List<String> boxIds() => [for (final e in box) e.id];

  setUp(() => ids = 0);

  group('supersets', () {
    test('choosing two exercises makes a superset, reaching the parent', () {
      final cubit = build(list([('a', null), ('b', null), ('c', null)]))
        ..supersetPressed()
        ..supersetRowPressed('a');
      expect(cubit.state.isSelectingSuperset, isTrue);
      expect(cubit.state.canConfirmSuperset, isFalse);
      cubit.supersetRowPressed('c');
      expect(cubit.state.supersetSelection, {'a', 'c'});
      cubit.supersetConfirmed();

      expect(cubit.state.isSelectingSuperset, isFalse);
      expect(boxIds(), ['a', 'c', 'b']);
      expect(box[0].supersetGroupId, isNotNull);
      expect(box[0].supersetGroupId, box[1].supersetGroupId);
      expect(WorkoutEditorRules.supersetLetters(box).values, ['A']);
      expect(analytics.names, ['DefineWorkoutView_Superset_Created']);
      expect(analytics.parameters('DefineWorkoutView_Superset_Created'), {
        'exercise_count': 2,
      });
    });

    test(
      'a row ticked twice is unticked; outside selection it does nothing',
      () {
        final cubit = build(list([('a', null), ('b', null)]))
          ..supersetRowPressed('a');
        expect(cubit.state.supersetSelection, isEmpty);
        cubit
          ..supersetPressed()
          ..supersetRowPressed('a')
          ..supersetRowPressed('a');
        expect(cubit.state.supersetSelection, isEmpty);
        cubit.supersetConfirmed();
        expect(analytics.names, isEmpty);
      },
    );

    test('a single exercise cannot start a superset', () {
      final cubit = build(list([('a', null)]))..supersetPressed();
      expect(cubit.state.isSelectingSuperset, isFalse);
    });

    test('cancelling superset selection changes nothing', () {
      final cubit = build(list([('a', null), ('b', null)]))
        ..supersetPressed()
        ..supersetRowPressed('a')
        ..supersetRowPressed('b')
        ..supersetCancelled();
      expect(cubit.state.isSelectingSuperset, isFalse);
      expect(box.every((e) => e.supersetGroupId == null), isTrue);
    });

    test('removing or deleting a member of two dissolves the superset', () {
      final grouped = [('a', 'g'), ('b', 'g'), ('c', null)];

      build(list(grouped)).removedFromSuperset('a');
      expect(box.every((e) => e.supersetGroupId == null), isTrue);
      expect(analytics.names, ['DefineWorkoutView_Superset_Removed']);

      build(list(grouped)).removeExercise('b');
      expect(boxIds(), ['a', 'c']);
      expect(box.every((e) => e.supersetGroupId == null), isTrue);
    });

    test('moving a member moves its superset', () {
      build(list([('a', 'g'), ('b', 'g'), ('c', null)])).moveExercise(0, 3);
      expect(boxIds(), ['c', 'a', 'b']);
    });

    test('moving an exercise reorders the workout', () {
      build(list([('bench', null), ('row', null), ('squat', null)]))
          .moveExercise(2, 0);
      expect(boxIds(), ['squat', 'bench', 'row']);
    });

    test('edit mode turns on and off', () {
      final cubit = build(list([('a', null)]))..editingChanged(isEditing: true);
      expect(cubit.state.isEditing, isTrue);
      cubit.editingChanged(isEditing: false);
      expect(cubit.state.isEditing, isFalse);
    });
  });

  group('the list', () {
    test('removing an exercise reaches the parent, by its own id', () {
      final bench = fixtureLibraryExercise('bench');
      final cubit = build([
        fixtureSlot(bench, id: 'a'),
        fixtureSlot(bench, id: 'b'),
        fixtureSlot(fixtureLibraryExercise('row'), id: 'c'),
      ])..removeExercise('a');
      expect(boxIds(), ['b', 'c']);
      cubit.removeExercise('missing');
      expect(boxIds(), ['b', 'c']);
    });

    test('exercises picked land after those there, never twice', () {
      build([fixtureSlot(fixtureLibraryExercise('deadlift'), id: 'a')]).picked([
        fixtureLibraryExercise('bench'),
        fixtureLibraryExercise('deadlift'),
      ]);
      expect([for (final e in box) e.exercise.id], ['deadlift', 'bench']);
      expect(box.last.setTargets.single.setNumber, 1);
      expect(box.last.setRestTimers, isFalse);
    });

    test('an empty new workout opens the picker once', () {
      final cubit = build(const [])..appeared(autoOpens: true);
      expect(cubit.state.autoOpenedPicker, isTrue);
      final once = cubit.state;
      cubit
        ..editingChanged(isEditing: true)
        ..appeared(autoOpens: true);
      expect(cubit.state.autoOpenedPicker, isTrue);
      expect(cubit.state, isNot(once));
    });

    test('a workout with exercises does not open the picker', () {
      final cubit = build(list([('a', null)]))..appeared(autoOpens: true);
      expect(cubit.state.autoOpenedPicker, isFalse);
    });

    test('a rest day does not open the picker', () {
      final cubit = build(const [])..appeared(autoOpens: false);
      expect(cubit.state.autoOpenedPicker, isFalse);
    });

    test('set targets written by the editor reach the tapped exercise', () {
      final cubit = build(list([('a', null), ('b', null)]));
      final second = box[1];
      cubit.exerciseEdited(
        second.copyWith(
          setTargets: const [
            SetTarget(id: 's1', setNumber: 1, minReps: 6, maxReps: 8),
            SetTarget(id: 's2', setNumber: 2, minReps: 6, maxReps: 8),
          ],
        ),
      );
      expect([for (final t in box[1].setTargets) t.setNumber], [1, 2]);
      expect(box[1].setTargets.first.minReps, 6);
      expect(box[0].setTargets, hasLength(3));
    });

    test('appearing logs no screen event', () {
      build(const []);
      expect(analytics.names, isEmpty);
    });
  });
}
