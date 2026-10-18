import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

/// Fails every save, or every delete, when told to.
class _Library extends InMemoryTrainingLibraryRepository {
  new({super.exercises});

  bool failSaves = false;
  bool failDeletes = false;

  @override
  Future<void> saveUserExercise(ExerciseModel exercise) async {
    if (failSaves) throw StateError('rejected');
    await super.saveUserExercise(exercise);
  }

  @override
  Future<void> deleteUserExercise(String exerciseId) async {
    if (failDeletes) throw StateError('rejected');
    await super.deleteUserExercise(exerciseId);
  }
}

void main() {
  late AppBloc appBloc;
  late _Library library;
  late AnalyticsRecorder analytics;
  final mine = fixtureLibraryExercise('mine', name: 'My Curl');

  void signIn({UserModel? profile}) => when(() => appBloc.state).thenReturn(
    AppAuthenticated(
      const AuthUser(uid: 'friend', isAnonymous: false),
      profile: profile,
    ),
  );

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    signIn();
  });

  Future<void> pump(WidgetTester tester, String location) async {
    tester.view
      ..physicalSize = const Size(1200, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    library = _Library(exercises: [mine]);
    analytics = AnalyticsRecorder();
    await tester.pumpApp(
      const SizedBox(),
      appBloc: appBloc,
      analyticsRepository: analytics,
      router: libraryRouter(location),
      trainingLibraryRepository: library,
      programRepository: InMemoryProgramRepository(),
      workoutSessionRepository: InMemoryWorkoutSessionRepository(
        sessions: const [],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Names the exercise and picks [metric] as its first metric.
  Future<void> nameIt(
    WidgetTester tester, {
    String name = 'Zercher Fly',
    String metric = 'Reps',
  }) async {
    await tester.enterText(find.byKey(const Key('CreateExercise.name')), name);
    await tap(tester, find.byKey(const Key('CreateExercise.metricA')));
    await tap(tester, find.text(metric).last);
  }

  Finder cta(String key) => find.byKey(Key(key));

  bool enabled(WidgetTester tester, String key) =>
      tester.widget<AppCtaButton>(cta(key)).onPressed != null;

  group('from the exercise library', () {
    testWidgets('creates an exercise that then shows in the library', (
      tester,
    ) async {
      await pump(tester, '/training/exercises');
      await tap(tester, find.byKey(const Key('ExerciseList.create')));
      expect(find.text('Create Custom Exercise'), findsOneWidget);
      expect(enabled(tester, 'CreateExercise.next'), isFalse);

      await nameIt(tester);
      await tap(tester, find.byKey(const Key('CreateExercise.type')));
      await tap(tester, find.text('Upper Compound').last);
      await tap(tester, find.byKey(const Key('CreateExercise.laterality')));
      expect(
        find.text('Both sides of the body work together at the same time.'),
        findsOneWidget,
      );
      await tap(tester, find.text('Bilateral').last);
      await tap(tester, cta('CreateExercise.next'));

      expect(find.text('Select Muscles'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      await tap(tester, find.byKey(const Key('MuscleGroupPicker.chest')));
      expect(find.text('1 primary, 0 secondary'), findsOneWidget);
      await tap(tester, cta('MuscleGroupPicker.next'));

      expect(find.text('Select Equipment'), findsOneWidget);
      expect(enabled(tester, 'ExerciseEquipment.next'), isFalse);
      await tap(
        tester,
        find.byKey(const Key('ExerciseEquipment.resistance.0')),
      );
      expect(find.text('Resistance Equipment'), findsOneWidget);
      expect(find.text('Flat Bench'), findsNothing);
      await tap(tester, find.byKey(const Key('EquipmentPicker.barbell')));
      await tap(tester, find.byType(CloseButton));
      expect(find.text('Barbell'), findsOneWidget);
      await tap(tester, cta('ExerciseEquipment.next'));

      expect(find.text('Final Details'), findsOneWidget);
      await tap(tester, find.byTooltip('Increase, Range of Motion'));
      await tester.enterText(
        find.byKey(const Key('FinalExerciseDetails.alternateNames')),
        'Pec Fly, ',
      );
      await tester.pumpAndSettle();
      await tap(tester, cta('FinalExerciseDetails.next'));

      expect(find.text('Save Exercise'), findsOneWidget);
      expect(find.text('Zercher Fly'), findsOneWidget);
      expect(find.text('Pec Fly'), findsOneWidget);
      await tap(tester, cta('ExerciseSave.create'));

      expect(find.text('Save Exercise'), findsNothing);
      expect(find.text('Zercher Fly'), findsOneWidget);
      final created = (await library.watchUserExercises('friend').first)
          .firstWhere((exercise) => exercise.name == 'Zercher Fly');
      expect(created.trackableMetrics, [TrackableExerciseMetric.reps]);
      expect(created.muscleGroups, {Muscles.chest: MuscleTargetType.primary});
      expect(created.rangeOfMotion, 1);
      expect(created.alternateNames, ['Pec Fly']);
      expect(
        analytics.names,
        containsAllInOrder([
          'ExercisesView_AddExercisePressed',
          'CreateExerciseView_Appear',
          'MuscleGroupPickerView_Appear',
          'ExerciseEquipmentView_Appear',
          'EquipmentPickerView_Appear',
          'EquipmentPickerView_Disappear',
          'FinalExerciseDetailsView_Appear',
          'ExerciseSaveView_Appear',
          'CreateExercise_Start',
          'CreateExercise_Success',
        ]),
      );
    });

    testWidgets('asks before discarding what was typed', (tester) async {
      await pump(tester, '/training/exercises');
      await tap(tester, find.byKey(const Key('ExerciseList.create')));
      await tester.enterText(
        find.byKey(const Key('CreateExercise.name')),
        'Fly',
      );
      await tap(tester, find.byType(CloseButton));
      expect(find.text('Discard Changes?'), findsOneWidget);
      await tap(tester, find.text('Keep Editing'));
      expect(find.text('Create Custom Exercise'), findsOneWidget);

      await tap(tester, find.byType(CloseButton));
      await tap(tester, find.text('Discard Changes'));
      expect(find.text('Create Custom Exercise'), findsNothing);
    });

    testWidgets('back steps through the flow, then asks before leaving', (
      tester,
    ) async {
      await pump(tester, '/training/exercises');
      await tap(tester, find.byKey(const Key('ExerciseList.create')));
      await nameIt(tester);
      await tap(tester, cta('CreateExercise.next'));
      expect(find.text('Select Muscles'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Select Muscles'), findsNothing);
      expect(find.text('Create Custom Exercise'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard Changes?'), findsOneWidget);
    });

    testWidgets("opens from Training's + menu", (tester) async {
      await pump(tester, '/training');
      await tap(tester, find.byTooltip('Add training'));
      await tap(tester, find.text('New Exercise'));
      expect(find.text('Create Custom Exercise'), findsOneWidget);
    });

    testWidgets('closes at once when nothing was typed', (tester) async {
      await pump(tester, '/training/exercises');
      await tap(tester, find.byKey(const Key('ExerciseList.create')));
      await tap(tester, find.byType(CloseButton));
      expect(find.text('Create Custom Exercise'), findsNothing);
    });

    testWidgets('a metric can be set back to none', (tester) async {
      await pump(tester, '/training/exercises');
      await tap(tester, find.byKey(const Key('ExerciseList.create')));
      await nameIt(tester, metric: 'Duration');
      expect(enabled(tester, 'CreateExercise.next'), isTrue);
      await tap(tester, find.byKey(const Key('CreateExercise.metricA')));
      await tap(tester, find.text('None').last);
      expect(enabled(tester, 'CreateExercise.next'), isFalse);
    });

    testWidgets('says when the exercise could not be created', (tester) async {
      await pump(tester, '/training/exercises');
      library.failSaves = true;
      await tap(tester, find.byKey(const Key('ExerciseList.create')));
      await nameIt(tester);
      await tap(tester, cta('CreateExercise.next'));
      await tap(tester, cta('MuscleGroupPicker.next'));
      await tap(tester, find.byKey(const Key('ExerciseEquipment.bodyweight')));
      await tap(tester, cta('ExerciseEquipment.next'));
      await tap(tester, cta('FinalExerciseDetails.next'));
      await tap(tester, cta('ExerciseSave.create'));

      expect(find.text('Unable to Create Exercise'), findsOneWidget);
      await tap(tester, find.text('OK'));
      expect(find.text('Save Exercise'), findsOneWidget);
      expect(enabled(tester, 'ExerciseSave.create'), isTrue);
    });
  });

  group('the steps', () {
    Future<void> toEquipment(WidgetTester tester) async {
      await pump(tester, '/training/exercises');
      await tap(tester, find.byKey(const Key('ExerciseList.create')));
      await nameIt(tester, metric: 'Weight');
      await tap(tester, cta('CreateExercise.next'));
      await tap(tester, cta('MuscleGroupPicker.next'));
    }

    testWidgets('muscles cycle, count and reset', (tester) async {
      await pump(tester, '/training/exercises');
      await tap(tester, find.byKey(const Key('ExerciseList.create')));
      await nameIt(tester);
      await tap(tester, cta('CreateExercise.next'));

      final chest = find.byKey(const Key('MuscleGroupPicker.chest'));
      await tap(tester, chest);
      await tap(tester, chest);
      await tap(tester, find.byKey(const Key('MuscleGroupPicker.quads')));
      expect(find.text('1 primary, 1 secondary'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      await tap(tester, find.byKey(const Key('MuscleGroupPicker.reset')));
      expect(find.text('0 primary, 0 secondary'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('variations are added, required and deleted', (tester) async {
      await toEquipment(tester);
      expect(
        find.text('Equipment that adds load to the exercise · Required'),
        findsOneWidget,
      );
      await tap(tester, find.byKey(const Key('ExerciseEquipment.bodyweight')));
      expect(
        find.text('Equipment that adds load to the exercise · Optional'),
        findsOneWidget,
      );

      await tap(
        tester,
        find.byKey(const Key('ExerciseEquipment.addVariation')),
      );
      expect(find.text('Variation 2'), findsOneWidget);
      await tap(tester, find.byKey(const Key('ExerciseEquipment.delete.1')));
      expect(find.text('Variation 2'), findsNothing);
      expect(find.text('Delete variation'), findsNothing);
    });

    testWidgets('the support picker filters by name', (tester) async {
      await toEquipment(tester);
      await tap(tester, find.byKey(const Key('ExerciseEquipment.support.0')));
      expect(find.text('Support Equipment'), findsWidgets);
      expect(find.text('Barbell'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No Results for “zzz”'), findsOneWidget);
    });

    testWidgets('a loaded bodyweight exercise cannot continue', (tester) async {
      await toEquipment(tester);
      await tap(tester, find.byKey(const Key('ExerciseEquipment.bodyweight')));
      await tap(tester, cta('ExerciseEquipment.next'));

      expect(
        find.textContaining('A bodyweight exercise cannot track a load'),
        findsOneWidget,
      );
      expect(enabled(tester, 'FinalExerciseDetails.next'), isFalse);
    });

    testWidgets('the contribution is checked and shown in the users unit', (
      tester,
    ) async {
      signIn(
        profile: const UserModel(
          userId: 'friend',
          submittedWeightKilograms: 80,
          submittedWeightUnitPreference: WeightUnitPreference.pounds,
        ),
      );
      await pump(tester, '/training/exercises');
      await tap(tester, find.byKey(const Key('ExerciseList.create')));
      await nameIt(tester);
      await tap(tester, cta('CreateExercise.next'));
      await tap(tester, cta('MuscleGroupPicker.next'));
      await tap(tester, find.byKey(const Key('ExerciseEquipment.bodyweight')));
      await tap(tester, cta('ExerciseEquipment.next'));

      final field = find.byKey(const Key('FinalExerciseDetails.contribution'));
      expect(find.text('About 132 lb at your current weight.'), findsOneWidget);
      await tester.enterText(field, '50');
      await tester.pumpAndSettle();
      expect(find.text('About 88 lb at your current weight.'), findsOneWidget);

      await tester.enterText(field, '140');
      await tester.pumpAndSettle();
      expect(find.text('Enter a number from 0 to 100.'), findsOneWidget);
      expect(enabled(tester, 'FinalExerciseDetails.next'), isFalse);

      await tester.enterText(field, '');
      await tester.pumpAndSettle();
      expect(
        find.text('The share of your body weight this exercise moves.'),
        findsOneWidget,
      );
    });
  });

  group('from the exercise picker', () {
    testWidgets('the new exercise comes back ticked, ready to add', (
      tester,
    ) async {
      await pump(tester, '/launcher');
      await tap(tester, find.text('Pick'));
      await tap(tester, find.byKey(const Key('ExerciseList.create')));
      await nameIt(tester, name: 'Zercher Hold', metric: 'Duration');
      await tap(tester, cta('CreateExercise.next'));
      await tap(tester, cta('MuscleGroupPicker.next'));
      await tap(tester, find.byKey(const Key('ExerciseEquipment.bodyweight')));
      await tap(tester, cta('ExerciseEquipment.next'));
      await tap(tester, cta('FinalExerciseDetails.next'));
      await tap(tester, cta('ExerciseSave.create'));

      expect(find.text('1 exercise selected'), findsOneWidget);
      await tap(tester, find.byTooltip('Add'));
      final created = (await library.watchUserExercises('friend').first)
          .firstWhere((exercise) => exercise.name == 'Zercher Hold');
      expect(find.text('Picked: ${created.id}'), findsOneWidget);
    });
  });

  group('deleting an exercise', () {
    Future<void> open(WidgetTester tester) async {
      await pump(tester, '/training/exercises/mine');
      await tap(tester, find.byKey(const Key('ExerciseDetail.options')));
      await tap(tester, find.text('Delete Exercise'));
      expect(
        find.text(
          "Are you sure you want to delete 'My Curl'? This action cannot "
          'be undone.',
        ),
        findsOneWidget,
      );
    }

    testWidgets('deletes the users own after asking', (tester) async {
      await open(tester);
      await tap(tester, find.text('Delete').last);
      expect(find.text('Custom Exercises'), findsOneWidget);
      expect(find.text('My Curl'), findsNothing);
      expect(
        analytics.names,
        containsAllInOrder([
          'ExerciseModelDetailView_DeleteExercise_Start',
          'ExerciseModelDetailView_DeleteExercise_Success',
        ]),
      );
    });

    testWidgets('says when it could not be deleted', (tester) async {
      await open(tester);
      library.failDeletes = true;
      await tap(tester, find.text('Delete').last);
      expect(find.text('Failed to delete exercise'), findsOneWidget);
    });

    testWidgets('offers nothing on a bundled exercise', (tester) async {
      await pump(tester, '/training/exercises');
      await tap(tester, find.text('Barbell Bench Press'));
      expect(find.byKey(const Key('ExerciseDetail.options')), findsNothing);
    });
  });
}
