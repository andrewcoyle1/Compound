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
    final cubit = DeleteWorkoutCubit(library: library, analytics: analytics);
    addTearDown(cubit.close);

    await cubit.delete('friend', 'w');

    expect(cubit.state, DeleteWorkoutStatus.deleted);
    expect(await library.watchUserWorkoutTemplates('friend').first, isEmpty);
    expect(analytics.names, [
      'WorkoutTemplateDetailView_DeleteWorkout_Start',
      'WorkoutTemplateDetailView_DeleteWorkout_Success',
    ]);
  });

  test(
    'a refused delete fails, and a second tap mid-delete is ignored',
    () async {
      final library = _Library()..fails = true;
      final analytics = AnalyticsRecorder();
      final cubit = DeleteWorkoutCubit(library: library, analytics: analytics);
      addTearDown(cubit.close);

      final first = cubit.delete('friend', 'w');
      await cubit.delete('friend', 'w');
      await first;

      expect(cubit.state, DeleteWorkoutStatus.failed);
      expect(analytics.names, [
        'WorkoutTemplateDetailView_DeleteWorkout_Start',
        'WorkoutTemplateDetailView_DeleteWorkout_Fail',
      ]);
    },
  );
}
