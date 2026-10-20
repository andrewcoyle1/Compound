import 'package:compound/workout_tracker/logic/live_activity_content.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart' show DistanceUnit;

final _now = DateTime(2026, 10, 16, 18);

WorkoutSetModel _set(
  String id, {
  int index = 1,
  bool warmup = false,
  bool done = false,
  double? kg = 60,
  int? reps = 8,
  String? side,
  String? kind,
  String? parent,
  DateTime? at,
}) => WorkoutSetModel(
  id: id,
  authorId: 'u',
  index: index,
  isWarmup: warmup,
  dateCreated: _now,
  weightKg: kg,
  reps: reps,
  sideRawValue: side,
  kindRawValue: kind,
  parentSetId: parent,
  completedAt: done ? (at ?? _now.subtract(const Duration(minutes: 1))) : null,
);

WorkoutExerciseModel _exercise(
  String id,
  List<WorkoutSetModel> sets, {
  TrackingMode mode = TrackingMode.weightReps,
}) => WorkoutExerciseModel(
  id: id,
  authorId: 'u',
  templateId: 't-$id',
  name: 'Exercise $id',
  imageName: 'Image$id',
  trackingMode: mode,
  index: 0,
  sets: sets,
);

LiveActivityState _state(
  List<WorkoutExerciseModel> exercises, {
  int index = 0,
  DateTime? restEnd,
  bool plansSets = false,
  ExerciseWeightUnit unit = ExerciseWeightUnit.kilograms,
}) => liveActivityState(
  session: WorkoutSessionModel(
    id: 's',
    authorId: 'u',
    name: 'Push Day',
    dateCreated: _now,
    dateModified: _now,
    exercises: exercises,
  ),
  isActive: true,
  currentExerciseIndex: index,
  now: _now,
  restEnd: restEnd,
  plansSets: plansSets,
  weightUnit: (_) => unit,
  distanceUnit: (_) => DistanceUnit.miles,
);

void main() {
  group('liveActivityState', () {
    test('describes the target, counted within its group', () {
      final state = _state([
        _exercise('a', [
          _set('w', warmup: true, done: true),
          _set('1', index: 2, done: true),
          _set('2', index: 3, kg: 62.5),
          _set('3', index: 4),
        ]),
      ], unit: ExerciseWeightUnit.pounds);
      expect(state.currentExerciseName, 'Exercise a');
      expect(state.currentExerciseImageName, 'Imagea');
      expect(state.targetSetId, '2');
      expect(state.targetWeightKg, 62.5);
      expect(state.currentExerciseCompletedSetsCount, 1);
      expect(state.currentExerciseTotalSetsCount, 3);
      expect(state.targetIsWarmup, isFalse);
      expect(state.completedSetsCount, 1);
      expect(state.totalSetsCount, 3);
      expect(state.progress, 1 / 3);
      expect(state.weightUnit, LiveActivityWeightUnit.pounds);
      expect(state.distanceUnit, LiveActivityDistanceUnit.miles);
      expect(state.canComplete, isTrue);
      expect(state.lastLoggedSetId, isNull);
      expect(state.isAllSetsComplete, isFalse);
    });

    test('moves a finished exercise on, and names the set the rest is '
        'after', () {
      final state = _state([
        _exercise('a', [_set('1', done: true, reps: 6)]),
        _exercise('b', [_set('2', reps: null, side: 'left')]),
      ], restEnd: _now.add(const Duration(minutes: 2)));
      expect(state.currentExerciseIndex, 1);
      expect(state.lastLoggedSetId, '1');
      expect(state.lastLoggedReps, 6);
      expect(state.restLeadsToNewExercise, isTrue);
      expect(state.targetSide, 'L');
      expect(state.canComplete, isFalse);
    });

    test('has no target once every set is logged', () {
      final state = _state([
        _exercise('a', [_set('1', done: true)]),
      ]);
      expect(state.isAllSetsComplete, isTrue);
      expect(state.targetSetId, isNull);
      expect(state.canComplete, isFalse);
      expect(state.progress, 1);
      expect(_state(const []).currentExerciseName, isNull);
    });

    test('with the set plan, counts a set once its pieces are logged and '
        'names the piece', () {
      final state = _state([
        _exercise('a', [
          _set('1', kind: 'drop', done: true),
          _set('d1', index: 2, kind: 'drop', parent: '1', done: true),
          _set('d2', index: 3, kind: 'drop', parent: '1'),
          _set('2', index: 4),
        ]),
      ], plansSets: true);
      expect(state.targetSetId, 'd2');
      expect(state.completedSetsCount, 0);
      expect(state.targetKind, LiveActivitySetKind.drop);
      expect(
        state.targetPiece,
        const LiveActivityPiece(index: 3, count: 3, isDrop: true),
      );
      expect(state.progress, (0 + 2 / 3) / 2);
    });
  });

  group('pieceOf', () {
    r.WorkoutSet set(
      String id, {
      r.SetKind kind = r.SetKind.standard,
      String? parent,
    }) => r.WorkoutSet(id: id, kind: kind, parentSetId: parent);

    test('names a technique piece as itself, and a plain set has none', () {
      final sets = [
        set('1', kind: r.SetKind.myo),
        set('p', kind: r.SetKind.partials, parent: '1'),
      ];
      expect(
        pieceOf(sets[0], sets),
        const LiveActivityPiece(
          index: 1,
          count: 2,
          isDrop: false,
          technique: LiveActivitySetKind.partials,
        ),
      );
      expect(pieceOf(set('x'), [set('x')]), isNull);
      expect(pieceOf(set('y', parent: 'gone'), [set('y')]), isNull);
      expect(kindOf(set('x'), [set('x')]), isNull);
      expect(kindOf(sets[1], sets), LiveActivitySetKind.myo);
    });
  });

  group('exerciseIndexWithWorkLeft', () {
    r.WorkoutExercise exercise({required bool done}) => r.WorkoutExercise(
      id: '$done',
      sets: [r.WorkoutSet(id: 's', completedAt: done ? _now : null)],
    );

    test('wraps to the first with work left, else stays', () {
      final list = [exercise(done: false), exercise(done: true)];
      expect(exerciseIndexWithWorkLeft(1, list), 0);
      expect(exerciseIndexWithWorkLeft(0, list), 0);
      expect(exerciseIndexWithWorkLeft(5, list), 5);
      expect(exerciseIndexWithWorkLeft(0, [exercise(done: true)]), 0);
    });
  });
}
