import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:compound/create_exercise/create_exercise.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../../helpers/helpers.dart';

/// Saves when [gate] completes, failing when [fails].
class _Library extends InMemoryTrainingLibraryRepository {
  bool fails = false;
  Completer<void>? gate;
  final saved = <ExerciseModel>[];

  @override
  Future<void> saveUserExercise(ExerciseModel exercise) async {
    await gate?.future;
    if (fails) throw StateError('rejected');
    saved.add(exercise);
  }
}

/// Mirrors `ExerciseSavePresenterTests`; what the stored exercise carries
/// is in `exercise_draft_test.dart`.
void main() {
  late _Library library;
  late AnalyticsRecorder analytics;
  const draft = ExerciseDraft(
    name: 'Bench Press',
    metricA: TrackableExerciseMetric.reps,
  );
  final now = DateTime.utc(2026, 10, 16);

  ExerciseSaveCubit build({String? uid = 'user-42'}) {
    library = _Library();
    analytics = AnalyticsRecorder();
    final cubit = ExerciseSaveCubit(
      draft: draft,
      uid: uid,
      library: library,
      analytics: analytics,
      now: () => now,
      newId: () => 'new-id',
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('the exercise belongs to the signed-in user', () async {
    final cubit = build();
    expect(cubit.created, isNull);
    await cubit.create();
    expect(cubit.state, ExerciseSaveStatus.saved);
    final stored = library.saved.single;
    expect(cubit.created, stored);
    expect(stored.id, 'new-id');
    expect(stored.authorId, 'user-42');
    expect(stored.isSystemExercise, isFalse);
    expect(stored.dateCreated, now);
  });

  test('a second tap during a save stores nothing extra', () async {
    final cubit = build();
    library.gate = Completer();
    final first = cubit.create();
    expect(cubit.state, ExerciseSaveStatus.saving);
    await cubit.create();
    library.gate!.complete();
    await first;
    expect(library.saved, hasLength(1));
    expect(cubit.state, ExerciseSaveStatus.saved);
  });

  test('nothing is stored when nobody is signed in', () async {
    final cubit = build(uid: null);
    await cubit.create();
    expect(library.saved, isEmpty);
    expect(cubit.state, ExerciseSaveStatus.failed);
  });

  test('a failed save stores nothing', () async {
    final cubit = build();
    library.fails = true;
    await cubit.create();
    expect(library.saved, isEmpty);
    expect(cubit.state, ExerciseSaveStatus.failed);
    cubit.failureShown();
    expect(cubit.state, ExerciseSaveStatus.reviewing);
  });

  test('creating an exercise reports start then success', () async {
    await build().create();
    expect(analytics.names, ['CreateExercise_Start', 'CreateExercise_Success']);
  });

  test('a failed save reports the failure', () async {
    final cubit = build();
    library.fails = true;
    await cubit.create();
    expect(analytics.names, ['CreateExercise_Start', 'CreateExercise_Fail']);
    expect(analytics.events.last.type, LogType.severe);
  });

  test('no signed-in user reports the failure', () async {
    await build(uid: null).create();
    expect(analytics.names, ['CreateExercise_Start', 'CreateExercise_Fail']);
  });

  test('appearing is tracked as a screen view', () {
    build()
      ..appeared()
      ..disappeared();
    expect(analytics.names, [
      'ExerciseSaveView_Appear',
      'ExerciseSaveView_Disappear',
    ]);
  });
}
