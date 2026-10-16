import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';

import '../helpers/program_fixtures.dart';

// Ported from Swift's WorkoutSessionTemplateBuilderTests.
void main() {
  final now = DateTime.utc(2026, 10, 15, 12);
  late int count;
  String newId() => 'id-${++count}';

  setUp(() => count = 0);

  WorkoutSetModel set(
    int index, {
    int? reps,
    SetSide? side,
    bool isWarmup = false,
    String? parentSetId,
  }) => WorkoutSetModel(
    id: 'set-$index-${side?.value ?? 'both'}',
    authorId: 'friend',
    index: index,
    reps: reps,
    weightKg: 60,
    sideRawValue: side?.value,
    isWarmup: isWarmup,
    parentSetId: parentSetId,
    completedAt: now,
    dateCreated: now,
  );

  WorkoutExerciseModel logged(
    String name, {
    required String templateId,
    required int index,
    List<WorkoutSetModel>? sets,
    String? supersetGroupId,
    String? planNotes,
    int? restSeconds,
    String? linkUrl,
    List<String> substituteExerciseIds = const [],
    String? notes,
  }) => WorkoutExerciseModel(
    id: 'logged-$index',
    authorId: 'friend',
    templateId: templateId,
    name: name,
    trackingMode: TrackingMode.weightReps,
    index: index,
    sets: sets ?? [set(1, reps: 10)],
    supersetGroupId: supersetGroupId,
    planNotes: planNotes,
    restSeconds: restSeconds,
    linkUrl: linkUrl,
    substituteExerciseIds: substituteExerciseIds,
    notes: notes,
  );

  WorkoutSessionModel session(
    List<WorkoutExerciseModel> exercises, {
    String name = 'Push Day',
  }) => WorkoutSessionModel(
    id: 'session-x',
    authorId: 'friend',
    name: name,
    dateCreated: now,
    dateModified: now,
    exercises: exercises,
  );

  WorkoutTemplateModel? build(
    WorkoutSessionModel session, {
    required List<ExerciseModel> library,
    List<String> existingNames = const [],
  }) => workoutTemplateFromSession(
    session,
    library: library,
    existing: [
      for (final name in existingNames)
        WorkoutTemplateModel(
          workoutId: name,
          authorId: 'me',
          name: name,
          dateCreated: now,
          dateModified: now,
          exercises: const [],
        ),
    ],
    authorId: 'me',
    copyName: (name) => '$name (copy)',
    now: now,
    newId: newId,
  );

  ExerciseModel exercise(String id, String name) =>
      fixtureExercise(name, id: id);

  group('workoutTemplateFromSession', () {
    test('resolves by id, then by name, and skips the rest', () {
      final bench = exercise('system-bench', 'Bench Press');
      final myRow = exercise('my-row', 'Cable Row');
      // The id wins even when the name disagrees.
      final template = build(
        session([
          logged('Flat Bench', templateId: 'system-bench', index: 1),
          logged('Mystery Lift', templateId: 'friend-only', index: 2),
          logged(' cable row', templateId: 'friends-cable-row', index: 3),
        ]),
        library: [myRow, bench],
      )!;

      expect(template.exercises.map((e) => e.exercise.id), [
        'system-bench',
        'my-row',
      ]);
      expect(template.authorId, 'me');
      expect(template.name, 'Push Day');
      expect(template.dateCreated, now);
      expect(template.dateModified, now);
      expect(template.exercises.first.setRestTimers, isFalse);
    });

    test('keeps the session order', () {
      final template = build(
        session([
          logged('B', templateId: 'b', index: 2),
          logged('A', templateId: 'a', index: 1),
        ]),
        library: [exercise('b', 'B'), exercise('a', 'A')],
      )!;

      expect(template.exercises.map((e) => e.exercise.id), ['a', 'b']);
    });

    test('makes a target of each working set only', () {
      final targets = build(
        session([
          logged(
            'Bench Press',
            templateId: 'bench',
            index: 1,
            sets: [
              set(1, reps: 12, isWarmup: true),
              set(2, reps: 10),
              set(3, reps: 8),
              set(4, reps: 6),
            ],
          ),
        ]),
        library: [exercise('bench', 'Bench Press')],
      )!.exercises.first.setTargets;

      expect(targets.map((t) => t.setNumber), [1, 2, 3]);
      expect(targets.map((t) => t.minReps), [10, 8, 6]);
      expect(targets.map((t) => t.maxReps), [10, 8, 6]);
      expect(
        targets.map((t) => t.setType),
        everyElement(SetTargetSetType.standard),
      );
    });

    test('makes one target of a left and right pair', () {
      final targets = build(
        session([
          logged(
            'Single Arm Row',
            templateId: 'row',
            index: 1,
            sets: [
              set(1, reps: 12, side: SetSide.left),
              set(1, reps: 12, side: SetSide.right),
              set(2, reps: 10, side: SetSide.left),
              set(2, reps: 10, side: SetSide.right),
            ],
          ),
        ]),
        library: [exercise('row', 'Single Arm Row')],
      )!.exercises.first.setTargets;

      expect(targets.map((t) => t.minReps), [12, 10]);
    });

    test('leaves out a drop, which belongs to its set', () {
      final targets = build(
        session([
          logged(
            'Bench Press',
            templateId: 'bench',
            index: 1,
            sets: [
              set(1, reps: 10),
              set(2, reps: 6, parentSetId: 'set-1-both'),
            ],
          ),
        ]),
        library: [exercise('bench', 'Bench Press')],
      )!.exercises.first.setTargets;

      expect(targets.map((t) => t.minReps), [10]);
    });

    test('gives an exercise with only warm-ups one default target', () {
      final targets = build(
        session([
          logged(
            'Bench Press',
            templateId: 'bench',
            index: 1,
            sets: [set(1, reps: 5, isWarmup: true)],
          ),
        ]),
        library: [exercise('bench', 'Bench Press')],
      )!.exercises.first.setTargets;

      expect(targets, hasLength(1));
      expect(targets.first.minReps, 8);
      expect(targets.first.maxReps, 12);
    });

    test('adds copy to the name only on a clash', () {
      final pushDay = session([
        logged('Bench Press', templateId: 'bench', index: 1),
      ]);
      final library = [exercise('bench', 'Bench Press')];

      expect(
        build(pushDay, library: library, existingNames: ['Pull Day'])!.name,
        'Push Day',
      );
      expect(
        build(pushDay, library: library, existingNames: ['push day'])!.name,
        'Push Day (copy)',
      );
    });

    test('builds nothing when no exercise resolves', () {
      expect(
        build(
          session([
            logged('Mystery Lift', templateId: 'friend-only', index: 1),
          ]),
          library: [exercise('bench', 'Bench Press')],
        ),
        isNull,
      );
    });

    test('puts the plan the session ran from back on the template', () {
      final template = build(
        session([
          logged(
            'Bench Press',
            templateId: 'bench',
            index: 1,
            supersetGroupId: 's1',
            planNotes: 'Pause on the chest',
            restSeconds: 150,
            linkUrl: 'https://example.com/bench',
            substituteExerciseIds: ['dumbbell-press'],
            notes: 'Felt heavy',
          ),
          logged(
            'Cable Fly',
            templateId: 'fly',
            index: 2,
            supersetGroupId: 's1',
          ),
        ]),
        library: [
          exercise('bench', 'Bench Press'),
          exercise('fly', 'Cable Fly'),
        ],
      )!;
      final first = template.exercises.first;

      expect(first.notes, 'Pause on the chest');
      expect(first.restSeconds, 150);
      expect(first.linkUrl, 'https://example.com/bench');
      expect(first.substituteExerciseIds, ['dumbbell-press']);
      expect(template.exercises.map((e) => e.supersetGroupId), ['s1', 's1']);
    });

    test('dissolves a superset left with one exercise', () {
      final template = build(
        session([
          logged(
            'Bench Press',
            templateId: 'bench',
            index: 1,
            supersetGroupId: 's1',
          ),
          logged(
            'Mystery Lift',
            templateId: 'friend-only',
            index: 2,
            supersetGroupId: 's1',
          ),
        ]),
        library: [exercise('bench', 'Bench Press')],
      )!;

      expect(template.exercises.map((e) => e.supersetGroupId), [null]);
    });

    test('defaults to random ids', () {
      final template = workoutTemplateFromSession(
        session([logged('Bench Press', templateId: 'bench', index: 1)]),
        library: [exercise('bench', 'Bench Press')],
        existing: const [],
        authorId: 'me',
        copyName: (name) => name,
        now: now,
      )!;

      expect(template.workoutId, hasLength(36));
    });
  });
}
