import 'package:compound/workout_editor/workout_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../../helpers/helpers.dart';

class _Library extends InMemoryTrainingLibraryRepository {
  new({super.workoutTemplates});

  bool fails = false;

  @override
  Future<void> deleteWorkoutTemplate(String uid, String workoutId) async {
    if (fails) throw StateError('refused');
    await super.deleteWorkoutTemplate(uid, workoutId);
  }
}

void main() {
  test('deletes the workout between start and success', () async {
    final library = _Library(workoutTemplates: [fixtureTemplate('w')]);
    final analytics = AnalyticsRecorder();

    await WorkoutDeleter(
      library: library,
      analytics: analytics,
    ).delete('friend', 'w');

    expect(await library.watchUserWorkoutTemplates('friend').first, isEmpty);
    expect(analytics.names, [
      'WorkoutTemplateDetailView_DeleteWorkout_Start',
      'WorkoutTemplateDetailView_DeleteWorkout_Success',
    ]);
  });

  test('a refused delete is recorded and rethrown', () async {
    final library = _Library()..fails = true;
    final analytics = AnalyticsRecorder();

    await expectLater(
      WorkoutDeleter(
        library: library,
        analytics: analytics,
      ).delete('friend', 'w'),
      throwsStateError,
    );
    expect(analytics.names, [
      'WorkoutTemplateDetailView_DeleteWorkout_Start',
      'WorkoutTemplateDetailView_DeleteWorkout_Fail',
    ]);
  });
}
