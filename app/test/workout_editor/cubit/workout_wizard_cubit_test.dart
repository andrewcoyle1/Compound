import 'package:compound/workout_editor/workout_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../../helpers/helpers.dart';

/// Saves a turn later, failing when [fails].
class _Library extends InMemoryTrainingLibraryRepository {
  bool fails = false;
  final saved = <WorkoutTemplateModel>[];

  @override
  Future<void> saveWorkoutTemplate(WorkoutTemplateModel template) async {
    await Future<void>.delayed(Duration.zero);
    if (fails) throw StateError('rejected');
    saved.add(template);
  }
}

GymProfileModel _gym(String id) => GymProfileModel.fromFirestore({
  GymProfileModelKeys.id: id,
  GymProfileModelKeys.authorId: 'friend',
  GymProfileModelKeys.name: id,
});

/// Mirrors `CreateWorkoutFlowPresenterTests`' name and gym steps and
/// `CreateWorkoutWrapperPresenterTests`.
void main() {
  late _Library library;
  late AnalyticsRecorder analytics;
  final now = DateTime.utc(2026, 10, 15);
  final squat = fixtureSlot(fixtureLibraryExercise('squat'), id: 'a');

  WorkoutWizardCubit build({
    String? uid = 'friend',
    WorkoutTemplateModel? template,
  }) {
    library = _Library();
    analytics = AnalyticsRecorder();
    final cubit = WorkoutWizardCubit(
      uid: uid,
      template: template,
      library: library,
      analytics: analytics,
      now: () => now,
      newId: () => 'new-id',
    );
    addTearDown(cubit.close);
    return cubit;
  }

  final original = WorkoutTemplateModel(
    workoutId: 'wt-1',
    authorId: 'friend',
    name: 'Leg Day',
    description: 'keep',
    gymProfileId: 'gym-1',
    dateCreated: DateTime.utc(2026),
    dateModified: DateTime.utc(2026),
    exercises: [squat],
  );

  group('naming it', () {
    test('a workout cannot be named nothing', () {
      final cubit = build()..nameChanged('   \n ');
      expect(cubit.state.canContinue, isFalse);
      cubit.nameChanged('Push Day');
      expect(cubit.state.canContinue, isTrue);
    });

    test('the name is trimmed before it travels', () {
      final cubit = build()
        ..nameChanged('  Push Day \n')
        ..continued([_gym('a'), _gym('b')]);
      expect(cubit.state.gym, isNull);
      expect(cubit.state.name, 'Push Day');
    });

    test('editing opens with the existing name and exercises', () {
      final cubit = build(template: original);
      expect(cubit.state.name, 'Leg Day');
      expect(cubit.state.isEditing, isTrue);
      expect(cubit.state.exercises.single.id, 'a');
    });

    test('editing skips the gym step while the gym exists', () {
      final cubit = build(template: original)
        ..continued([_gym('gym-1'), _gym('b')]);
      expect(cubit.state.gym?.id, 'gym-1');
    });

    test('a single gym skips the gym step; several ask', () {
      expect((build()..continued([_gym('gym-1')])).state.gym?.id, 'gym-1');
      // Backing out and continuing again asks afresh.
      final several = build()
        ..gymChosen(_gym('a'))
        ..continued([_gym('a'), _gym('b')]);
      expect(several.state.gym, isNull);
    });

    test('editing asks for a gym when the old one is gone', () {
      expect(
        (build(
          template: original,
        )..continued([_gym('a'), _gym('b')])).state.gym,
        isNull,
      );
    });

    test('the screens are tracked', () {
      build()
        ..appeared('NameWorkoutView')
        ..disappeared('NameWorkoutView')
        ..appeared('ChooseGymProfileView');
      expect(analytics.names, [
        'NameWorkoutView_Appear',
        'NameWorkoutView_Disappear',
        'ChooseGymProfileView_Appear',
      ]);
    });
  });

  group('saving it', () {
    WorkoutWizardCubit ready({WorkoutTemplateModel? template, String? uid}) =>
        build(template: template, uid: uid ?? 'friend')
          ..nameChanged('Leg Day')
          ..gymChosen(_gym('gym-7'))
          ..exercisesChanged([squat]);

    test('the workout is saved under the name, gym and exercises', () async {
      final cubit = ready()..nameChanged('  Leg Day ');
      await cubit.save();
      final saved = library.saved.single;
      expect(saved.name, 'Leg Day');
      expect(saved.authorId, 'friend');
      expect(saved.workoutId, 'new-id');
      expect(saved.gymProfileId, 'gym-7');
      expect(saved.exercises.single.id, 'a');
      expect(cubit.state.status, WorkoutWizardStatus.saved);
      expect(analytics.names, [
        'DefineWorkoutWrapperView_SaveWorkout_Start',
        'DefineWorkoutWrapperView_SaveWorkout_Success',
      ]);
      expect(
        analytics.parameters('DefineWorkoutWrapperView_SaveWorkout_Start'),
        {'is_new': true},
      );
    });

    test('nothing is saved without a signed-in user', () async {
      final cubit = build(uid: null)
        ..gymChosen(_gym('g'))
        ..exercisesChanged([squat]);
      await cubit.save();
      expect(library.saved, isEmpty);
      expect(cubit.state.status, WorkoutWizardStatus.failed);
    });

    test('a failed save is survived', () async {
      final cubit = ready();
      library.fails = true;
      await cubit.save();
      expect(library.saved, isEmpty);
      expect(cubit.state.status, WorkoutWizardStatus.failed);
      expect(analytics.names.last, 'DefineWorkoutWrapperView_SaveWorkout_Fail');
      cubit.failureShown();
      expect(cubit.state.status, WorkoutWizardStatus.editing);
    });

    test('a workout with no exercises cannot be saved', () async {
      final cubit = build()..gymChosen(_gym('g'));
      expect(cubit.state.canSave, isFalse);
      await cubit.save();
      expect(library.saved, isEmpty);
    });

    test('editing saves under the original id', () async {
      final cubit = ready(template: original)..nameChanged('New Name');
      await cubit.save();
      final saved = library.saved.single;
      expect(saved.workoutId, 'wt-1');
      expect(saved.name, 'New Name');
      expect(saved.description, 'keep');
      expect(saved.dateCreated, DateTime.utc(2026));
      expect(saved.dateModified, now);
      expect(
        analytics.parameters('DefineWorkoutWrapperView_SaveWorkout_Success'),
        {'is_new': false},
      );
    });

    test('a second tap during a save is ignored', () async {
      final cubit = ready();
      final first = cubit.save();
      expect(cubit.state.canSave, isFalse);
      await cubit.save();
      await first;
      expect(library.saved, hasLength(1));
    });
  });
}
