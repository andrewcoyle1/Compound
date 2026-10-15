import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/training_library/training_library.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  late AppBloc appBloc;

  final plank = fixtureLibraryExercise(
    'plank',
    name: 'Plank',
    description: 'Hold it.',
    type: ExerciseType.core,
    alternateNames: ['Front Hold'],
  );
  final dips = fixtureLibraryExercise('dips', name: 'Dips');
  final template = fixtureTemplate(
    'mine',
    name: 'My Core',
    description: 'Abs, briefly.',
    exercises: [
      WorkoutTemplateExercise(
        id: 'a',
        exercise: plank,
        setTargets: const [
          SetTarget(id: 's1', setNumber: 1, minReps: 8, maxReps: 10),
          SetTarget(id: 's2', setNumber: 2, minReps: 8, maxReps: 12),
        ],
        setRestTimers: true,
        restSeconds: 90,
        warmupSetCount: 1,
        notes: 'Squeeze.',
        supersetGroupId: 'g',
        substituteExerciseIds: const ['dips'],
      ),
      fixtureSlot(dips, sets: 1, supersetGroupId: 'g'),
    ],
  );
  final block = fixtureMesocycle('m1', [
    fixtureTemplate('day-1', name: 'Block Day', exercises: [fixtureSlot(dips)]),
  ], name: 'My Block');

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(AuthUser(uid: 'friend', isAnonymous: false)),
    );
  });

  Future<void> pump(
    WidgetTester tester,
    String location, {
    ExercisePickerRequest request = const ExercisePickerRequest(),
    List<WorkoutSessionModel> sessions = const [],
  }) async {
    // Wide enough for the whole filter bar, tall enough for the sections.
    tester.view
      ..physicalSize = const Size(1600, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpApp(
      const SizedBox(),
      appBloc: appBloc,
      router: libraryRouter(location, request: request),
      trainingLibraryRepository: InMemoryTrainingLibraryRepository(
        exercises: [plank, dips],
        workoutTemplates: [template],
      ),
      programRepository: InMemoryProgramRepository(mesocycles: [block]),
      workoutSessionRepository: InMemoryWorkoutSessionRepository(
        sessions: sessions,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('TrainingPage', () {
    testWidgets('offers the library and opens each part', (tester) async {
      await pump(tester, '/training');
      expect(find.text('Library'), findsOneWidget);

      await tester.tap(find.text('Workout History'));
      await tester.pumpAndSettle();
      expect(find.text('History screen'), findsOneWidget);
    });

    testWidgets('searches exercises and workouts', (tester) async {
      await pump(tester, '/training');

      await tester.enterText(find.byType(TextField), 'plank');
      await tester.pumpAndSettle();
      expect(find.text('Plank'), findsOneWidget);
      expect(find.text('My Core'), findsOneWidget);

      await tester.tap(find.text('Plank'));
      await tester.pumpAndSettle();
      expect(find.text('Upper Compound'), findsNothing);
      expect(find.text('Core'), findsWidgets);
    });

    testWidgets('says when nothing matches', (tester) async {
      await pump(tester, '/training');
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No Results for “zzz”'), findsOneWidget);
    });

    testWidgets('opens the workouts and exercises', (tester) async {
      await pump(tester, '/training');
      await tester.tap(find.text('Workouts'));
      await tester.pumpAndSettle();
      expect(find.text('Custom Templates'), findsOneWidget);
    });
  });

  group(ExercisesPage, () {
    testWidgets('lists custom and official exercises', (tester) async {
      await pump(tester, '/training/exercises');
      expect(find.text('Custom Exercises'), findsOneWidget);
      expect(find.text('Official Exercises'), findsOneWidget);
      expect(find.text('Plank'), findsOneWidget);
      expect(find.text('Barbell Bench Press'), findsOneWidget);
    });

    testWidgets('searches, and clears the search', (tester) async {
      await pump(tester, '/training/exercises');
      await tester.enterText(find.byType(TextField), 'front hold');
      await tester.pumpAndSettle();
      expect(find.text('Plank'), findsOneWidget);
      expect(find.text('Official Exercises'), findsNothing);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Official Exercises'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No Results for “zzz”'), findsOneWidget);
    });

    testWidgets('filters by type until reset', (tester) async {
      await pump(tester, '/training/exercises');
      await tester.tap(find.text('Type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lower Isolation').last);
      await tester.pumpAndSettle();
      expect(find.text('Type (1)'), findsOneWidget);
      expect(find.text('No Custom Exercises'), findsOneWidget);
      expect(find.text('Plank'), findsNothing);

      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Plank'), findsOneWidget);
    });

    testWidgets('a filter matching nothing says so', (tester) async {
      await pump(tester, '/training/exercises');
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(MenuItemButton),
          matching: find.text('Custom Exercises'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stability'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5+'));
      await tester.pumpAndSettle();
      expect(find.text('No Matching Exercises'), findsOneWidget);
      expect(find.text('Stability 5+'), findsOneWidget);
    });

    testWidgets('opens an exercise', (tester) async {
      await pump(tester, '/training/exercises');
      await tester.tap(find.text('Plank'));
      await tester.pumpAndSettle();
      expect(find.text('Definition'), findsOneWidget);
    });
  });

  group(ExerciseDetailPage, () {
    testWidgets('describes a bundled exercise and its equipment', (
      tester,
    ) async {
      await pump(tester, '/training/exercises/system-barbell-bench-press');
      expect(find.text('Barbell Bench Press'), findsWidgets);
      expect(find.text('No history yet'), findsOneWidget);
      expect(find.text('Upper Compound'), findsOneWidget);
      expect(find.text('Reps × Weight'), findsOneWidget);
      expect(find.text('Variation 1'), findsOneWidget);
      expect(find.text('Barbell'), findsWidgets);
      expect(find.bySemanticsLabel('Chest, primary'), findsOneWidget);
    });

    testWidgets('shows the history, newest first', (tester) async {
      await pump(
        tester,
        '/training/exercises/plank',
        sessions: [
          fixtureSession(
            'a',
            exercises: [
              WorkoutExerciseModel(
                id: 'x',
                authorId: 'friend',
                templateId: 'plank',
                name: 'Plank',
                trackingMode: TrackingMode.weightReps,
                index: 1,
                sets: [fixtureSet(), fixtureSet(reps: 3, weightKg: 110)],
              ),
            ],
          ),
        ],
      );
      expect(find.textContaining('Performed 1 time'), findsOneWidget);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Session a'), findsOneWidget);
      expect(find.text('2 sets · 8 reps · top 110 kg'), findsOneWidget);
    });

    testWidgets('says when the exercise is gone', (tester) async {
      await pump(tester, '/training/exercises/gone');
      expect(
        find.text('This exercise is no longer in your library.'),
        findsOneWidget,
      );
    });
  });

  group(ExercisePickerPage, () {
    testWidgets('returns the exercises ticked', (tester) async {
      await pump(tester, '/launcher');
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      expect(find.text('Select at least one exercise'), findsOneWidget);

      await tester.tap(find.text('Plank'));
      await tester.pumpAndSettle();
      expect(find.text('1 exercise selected'), findsOneWidget);

      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Picked: plank'), findsOneWidget);
    });

    testWidgets('asks before losing ticked exercises', (tester) async {
      await pump(
        tester,
        '/launcher',
        request: const ExercisePickerRequest(committedIds: {'dips'}),
      );
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plank'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.text('Discard Changes?'), findsOneWidget);
      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();
      expect(find.text('1 exercise selected'), findsOneWidget);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard Changes'));
      await tester.pumpAndSettle();
      expect(find.text('Picked: null'), findsOneWidget);
    });

    testWidgets('closes at once with nothing ticked', (tester) async {
      await pump(tester, '/launcher');
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.text('Picked: null'), findsOneWidget);
    });

    testWidgets('opened on its own, closing goes to Training', (tester) async {
      await pump(tester, '/exercise-picker');
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.text('Library'), findsOneWidget);
    });
  });

  group(WorkoutsPage, () {
    testWidgets("lists the user's, the mesocycles' and the bundled", (
      tester,
    ) async {
      await pump(tester, '/training/workouts');
      expect(find.text('Custom Templates'), findsOneWidget);
      expect(find.text('My Block'), findsOneWidget);
      expect(find.text('Block Day'), findsOneWidget);
      expect(find.text('Pre-Built Templates'), findsOneWidget);
      expect(find.textContaining('workouts'), findsWidgets);
    });

    testWidgets('searches templates and days', (tester) async {
      await pump(tester, '/training/workouts');
      await tester.enterText(find.byType(TextField), 'block');
      await tester.pumpAndSettle();
      expect(find.text('Block Day'), findsOneWidget);
      expect(find.text('Workout Templates'), findsNothing);

      await tester.enterText(find.byType(TextField), 'my core');
      await tester.pumpAndSettle();
      expect(find.text('Workout Templates'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No Results for “zzz”'), findsOneWidget);
    });

    testWidgets('opens a workout', (tester) async {
      await pump(tester, '/training/workouts');
      await tester.tap(find.text('My Core'));
      await tester.pumpAndSettle();
      expect(find.text('2 Exercises'), findsOneWidget);
    });
  });

  group(WorkoutTemplateDetailPage, () {
    testWidgets("shows the plan's muscles and exercises", (tester) async {
      await pump(tester, '/training/workouts/mine');
      expect(find.text('Abs, briefly.'), findsOneWidget);
      expect(find.text('Target Muscles'), findsOneWidget);
      expect(find.text('Target: 3 sets'), findsOneWidget);
      expect(find.text('2 sets · 8–12'), findsOneWidget);
      expect(find.text('1 warm-up · Rest 1:30'), findsOneWidget);
      expect(find.text('Superset A'), findsNWidgets(2));
      expect(find.text('Squeeze.'), findsOneWidget);
      expect(find.text('Dips'), findsWidgets);

      await tester.tap(find.text('Plank'));
      await tester.pumpAndSettle();
      expect(find.text('Definition'), findsOneWidget);
    });

    testWidgets('a bundled template plans its muscles', (tester) async {
      await pump(tester, '/training/workouts/workout-push-1');
      expect(find.text('Push Day A'), findsOneWidget);
      expect(find.textContaining('Target: '), findsWidgets);
    });

    testWidgets('says when the workout is gone', (tester) async {
      await pump(tester, '/training/workouts/gone');
      expect(
        find.text('This workout is no longer in your library.'),
        findsOneWidget,
      );
    });
  });
}
