import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/programs/programs.dart';
import 'package:compound/training/training.dart';
import 'package:compound/training_library/training_library.dart';
import 'package:compound/workout_editor/workout_editor.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../../helpers/helpers.dart';
import '../../programs/helpers.dart';

GoRouter _router(String location) => GoRouter(
  initialLocation: location,
  routes: [
    GoRoute(
      path: '/training',
      builder: (_, _) => const TrainingPage(),
      routes: [
        ...programRoutes,
        ...workoutEditorRoutes,
        GoRoute(
          path: WorkoutsPage.path,
          name: WorkoutsPage.name,
          builder: (_, _) => const WorkoutsPage(),
          routes: [
            GoRoute(
              path: WorkoutTemplateDetailPage.path,
              name: WorkoutTemplateDetailPage.name,
              builder: (_, state) => WorkoutTemplateDetailPage.fromRoute(state),
            ),
          ],
        ),
        GoRoute(
          path: ExercisesPage.path,
          name: ExercisesPage.name,
          builder: (_, _) => const Text('Exercises screen'),
          routes: [
            GoRoute(
              path: ExerciseDetailPage.path,
              name: ExerciseDetailPage.name,
              builder: (_, _) => const Text('Exercise screen'),
            ),
          ],
        ),
        GoRoute(
          path: 'history',
          name: 'workoutHistory',
          builder: (_, _) => const Text('History screen'),
        ),
      ],
    ),
    GoRoute(
      path: ExercisePickerPage.path,
      name: ExercisePickerPage.name,
      builder: (_, state) => ExercisePickerPage(
        request: switch (state.extra) {
          final ExercisePickerRequest request => request,
          _ => const ExercisePickerRequest(),
        },
      ),
    ),
  ],
);

GymProfileModel _gym(String id, String name) => GymProfileModel.fromFirestore({
  GymProfileModelKeys.id: id,
  GymProfileModelKeys.authorId: programUid,
  GymProfileModelKeys.name: name,
});

void main() {
  late AppBloc appBloc;
  final press = fixtureLibraryExercise('aa-press', name: 'Aa Press');
  final row = fixtureLibraryExercise('ab-row', name: 'Ab Row');
  final mine = fixtureTemplate(
    'mine',
    name: 'My Push',
    exercises: [fixtureSlot(press, id: 'slot-press')],
  );

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(AuthUser(uid: programUid, isAnonymous: false)),
    );
  });

  Future<(ProgramWorld, InMemoryTrainingLibraryRepository)> pump(
    WidgetTester tester,
    String location, {
    List<GymProfileModel>? gyms,
    WorkoutSettings? settings,
  }) async {
    tester.view
      ..physicalSize = const Size(1200, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final world = ProgramWorld.seeded(
      mesocycles: [programMesocycle('m1'), programMesocycle('m2')],
      macrocycles: [
        programMacrocycle('p', ['m1']),
      ],
      active: 'm1',
    );
    final library = InMemoryTrainingLibraryRepository(
      exercises: [press, row],
      workoutTemplates: [mine],
      gymProfiles: gyms ?? [_gym('gym-1', 'Home Gym')],
      workoutSettings: [?settings],
    );
    await tester.pumpApp(
      const SizedBox(),
      appBloc: appBloc,
      router: _router(location),
      programRepository: world.programs,
      userRepository: world.users,
      workoutSessionRepository: world.sessions,
      trainingLibraryRepository: library,
      analyticsRepository: world.analytics,
      programsCubit: world.cubit()..userChanged(programUid),
    );
    await tester.pumpAndSettle();
    return (world, library);
  }

  Future<List<WorkoutTemplateModel>> templates(
    WidgetTester tester,
    InMemoryTrainingLibraryRepository library,
  ) async => (await tester.runAsync(
    () => library.watchUserWorkoutTemplates(programUid).first,
  ))!;

  Future<void> pick(WidgetTester tester, List<String> names) async {
    for (final name in names) {
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
  }

  /// Chooses the menu item showing [text].
  Future<void> choose(WidgetTester tester, String text) async {
    final item = find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate((w) => w is CheckedPopupMenuItem),
    );
    await tester.ensureVisible(item.last);
    await tester.pumpAndSettle();
    await tester.tap(item.last);
    await tester.pumpAndSettle();
  }

  group('the wizard', () {
    testWidgets('creates a workout from the + menu', (tester) async {
      final (world, library) = await pump(tester, '/training');
      await tester.tap(find.byTooltip('Add training'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Workout'));
      await tester.pumpAndSettle();
      expect(find.text('Name Workout'), findsOneWidget);

      final continueButton = find.byKey(const Key('NameWorkout.continue'));
      await tester.enterText(find.byKey(const Key('NameWorkout.name')), '  ');
      await tester.pump();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('Name Workout'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('NameWorkout.name')),
        ' Leg Day ',
      );
      await tester.pump();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // One gym: no chooser, and the picker opens on its own.
      expect(find.text('Select at least one exercise'), findsOneWidget);
      await pick(tester, ['Aa Press', 'Ab Row']);
      expect(find.text('Leg Day'), findsOneWidget);
      expect(find.text('2 Exercises'), findsOneWidget);

      // Targets: a set added.
      await tester.tap(find.text('Aa Press'));
      await tester.pumpAndSettle();
      expect(find.text('Targets'), findsOneWidget);
      await tester.tap(find.byKey(const Key('SetTarget.addSet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('SetTarget.save')));
      await tester.pumpAndSettle();
      expect(find.text('2 sets · 8–12'), findsOneWidget);

      await tester.tap(find.byKey(const Key('DefineWorkoutWrapper.save')));
      await tester.pumpAndSettle();
      expect(find.text('Leg Day'), findsNothing);
      final saved = (await templates(
        tester,
        library,
      )).firstWhere((t) => t.name == 'Leg Day');
      expect(saved.gymProfileId, 'gym-1');
      expect(
        [for (final e in saved.exercises) e.exercise.id],
        ['aa-press', 'ab-row'],
      );
      expect(saved.exercises.first.setTargets, hasLength(2));
      expect(
        world.analytics.names,
        containsAllInOrder([
          'NameWorkoutView_Appear',
          'DefineWorkoutWrapperView_Appear',
          'SetTargetView_Appear',
          'DefineWorkoutWrapperView_SaveWorkout_Success',
        ]),
      );
    });

    testWidgets('several gyms ask which one; backing out keeps exercises', (
      tester,
    ) async {
      await pump(
        tester,
        '/training/create-workout',
        gyms: [_gym('gym-1', 'Home Gym'), _gym('gym-2', 'Big Gym')],
      );
      await tester.enterText(find.byKey(const Key('NameWorkout.name')), 'Push');
      await tester.pump();
      await tester.tap(find.byKey(const Key('NameWorkout.continue')));
      await tester.pumpAndSettle();
      expect(find.text('Choose Gym Profile'), findsOneWidget);
      expect(find.text('Big Gym'), findsOneWidget);

      await tester.tap(find.text('Big Gym'));
      await tester.pumpAndSettle();
      await pick(tester, ['Aa Press']);
      expect(find.text('1 Exercise'), findsOneWidget);

      // Back to the gyms and forward again: the exercise is still there.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home Gym'));
      await tester.pumpAndSettle();
      expect(find.text('1 Exercise'), findsOneWidget);
    });

    testWidgets('with no gym, says one is needed', (tester) async {
      await pump(tester, '/training/create-workout', gyms: const []);
      await tester.enterText(find.byKey(const Key('NameWorkout.name')), 'Push');
      await tester.pump();
      await tester.tap(find.byKey(const Key('NameWorkout.continue')));
      await tester.pumpAndSettle();
      expect(find.text('No Gym Profiles'), findsOneWidget);
    });

    testWidgets('close leaves the wizard', (tester) async {
      await pump(tester, '/training');
      await tester.tap(find.byTooltip('Add training'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Workout'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('NameWorkout.close')));
      await tester.pumpAndSettle();
      expect(find.text('Name Workout'), findsNothing);
    });

    testWidgets('the workouts list opens a new workout', (tester) async {
      final (world, _) = await pump(tester, '/training/workouts');
      await tester.tap(find.byKey(const Key('Workouts.add')));
      await tester.pumpAndSettle();
      expect(find.text('Name Workout'), findsOneWidget);
      expect(world.analytics.names, contains('WorkoutsView_AddWorkoutPressed'));
    });
  });

  group('a library workout', () {
    testWidgets('is edited in place from its detail', (tester) async {
      final (_, library) = await pump(tester, '/training/workouts/mine');
      await tester.tap(find.byKey(const Key('WorkoutTemplateDetail.options')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Workout'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Workout'), findsOneWidget);
      expect(find.text('My Push'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('NameWorkout.name')),
        'My Pull',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('NameWorkout.continue')));
      await tester.pumpAndSettle();
      // The only gym, so straight to the exercises, which are kept.
      expect(find.text('1 Exercise'), findsOneWidget);
      await tester.tap(find.byKey(const Key('DefineWorkoutWrapper.save')));
      await tester.pumpAndSettle();

      final saved = await templates(tester, library);
      expect(saved.single.workoutId, 'mine');
      expect(saved.single.name, 'My Pull');
      expect(find.text('My Pull'), findsWidgets);
    });

    testWidgets('is deleted from its detail after asking', (tester) async {
      final (world, library) = await pump(tester, '/training/workouts/mine');
      await tester.tap(find.byKey(const Key('WorkoutTemplateDetail.options')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Workout'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          "Are you sure you want to delete 'My Push'? "
          'This action cannot be undone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(await templates(tester, library), isEmpty);
      expect(find.text('Custom Templates'), findsNothing);
      expect(
        world.analytics.names,
        contains('WorkoutTemplateDetailView_DeleteWorkout_Success'),
      );
    });

    testWidgets('a bundled workout has no options', (tester) async {
      final id = PrebuiltCatalogue.instance.workoutTemplates.first.workoutId;
      await pump(tester, '/training/workouts/$id');
      expect(
        find.byKey(const Key('WorkoutTemplateDetail.options')),
        findsNothing,
      );
    });

    testWidgets('a missing workout opens an empty wizard', (tester) async {
      await pump(tester, '/training/edit-workout/gone');
      expect(find.text('Name Workout'), findsOneWidget);
    });
  });

  group('the editor', () {
    Future<void> openNew(WidgetTester tester) async {
      await tester.enterText(find.byKey(const Key('NameWorkout.name')), 'Push');
      await tester.pump();
      await tester.tap(find.byKey(const Key('NameWorkout.continue')));
      await tester.pumpAndSettle();
    }

    testWidgets('groups a superset, letters it, and takes it apart', (
      tester,
    ) async {
      await pump(tester, '/training/create-workout');
      await openNew(tester);
      await pick(tester, ['Aa Press', 'Ab Row']);

      await tester.tap(find.byKey(const Key('DefineWorkout.edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('DefineWorkout.superset')));
      await tester.pumpAndSettle();
      expect(find.text('Select two or more exercises'), findsOneWidget);
      await tester.tap(find.text('Aa Press'));
      await tester.tap(find.text('Ab Row'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('DefineWorkout.confirmSuperset')));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('DefineWorkout.edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove from superset').first);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);

      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();
      expect(find.text('1 Exercise'), findsOneWidget);
      await tester.tap(find.byKey(const Key('DefineWorkout.edit')));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);

      // A swipe deletes too.
      await tester.drag(find.text('Ab Row'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('0 Exercises'), findsOneWidget);
    });

    testWidgets('superset selection can be cancelled', (tester) async {
      await pump(tester, '/training/create-workout');
      await openNew(tester);
      await pick(tester, ['Aa Press', 'Ab Row']);
      await tester.tap(find.byKey(const Key('DefineWorkout.edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('DefineWorkout.superset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('DefineWorkout.cancelSuperset')));
      await tester.pumpAndSettle();
      expect(find.text('Select two or more exercises'), findsNothing);
    });

    testWidgets("plans an exercise's sets, warm-ups, rest, link and weeks", (
      tester,
    ) async {
      await pump(
        tester,
        '/training/create-workout',
        settings: const WorkoutSettings(
          authorId: programUid,
          setPlanning: true,
        ),
      );
      await openNew(tester);
      await pick(tester, ['Aa Press']);
      await tester.tap(find.text('Aa Press'));
      await tester.pumpAndSettle();

      // Reps typed, and the RIR chosen.
      final set = find.byType(RepsField);
      await tester.enterText(set.first, '6');
      await tester.enterText(set.at(1), '10');
      await tester.tap(find.byTooltip('Set 1, reps in reserve'));
      await tester.pumpAndSettle();
      await choose(tester, '2');

      // The set's plan: a drop set.
      expect(find.text('Standard'), findsOneWidget);
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      expect(find.text('Set 1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('SetPlanDetail.kind')));
      await tester.pumpAndSettle();
      await choose(tester, 'Drop set');
      expect(find.text('2 drops'), findsOneWidget);
      await tester.tap(find.byTooltip('Increase'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('−30%'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('SetPlanDetail.done')));
      await tester.pumpAndSettle();
      expect(find.text('6–10 reps, then −30% ×3 to failure'), findsOneWidget);

      // Warm-ups and rest.
      await tester.tap(find.byKey(const Key('SetTarget.warmupSets')));
      await tester.pumpAndSettle();
      await choose(tester, '2');
      await tester.tap(find.byKey(const Key('SetTarget.rest')));
      await tester.pumpAndSettle();
      await choose(tester, '1:30');

      // A link that is not an address is refused.
      await tester.enterText(find.byKey(const Key('SetTarget.link')), 'nope');
      await tester.tap(find.byKey(const Key('SetTarget.save')));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a web address starting with http:// or https://'),
        findsWidgets,
      );
      await tester.enterText(
        find.byKey(const Key('SetTarget.link')),
        'https://example.com',
      );
      await tester.enterText(find.byKey(const Key('SetTarget.notes')), 'Slow');
      await tester.pumpAndSettle();

      // Weekly targets: one added, its own targets edited.
      await tester.tap(find.byKey(const Key('SetTarget.variesByWeek')));
      await tester.pumpAndSettle();
      expect(find.text('Same every week'), findsOneWidget);
      await tester.tap(find.byKey(const Key('WeeklyTargets.add')));
      await tester.pumpAndSettle();
      expect(find.text('From week 2'), findsWidgets);
      await tester.tap(find.byTooltip('Increase'));
      await tester.pumpAndSettle();
      expect(find.text('From week 3'), findsWidgets);
      await tester.tap(find.text('Targets').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('SetTarget.addSet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('SetTarget.save')));
      await tester.pumpAndSettle();
      expect(find.text('2 sets'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.text('Weeks 1–2: 1 set · From week 3: 2 sets'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('SetTarget.save')));
      await tester.pumpAndSettle();
      expect(
        find.text('2 warm-ups · 1:30 rest · notes · link · varies by week'),
        findsOneWidget,
      );
    });

    testWidgets('closing the targets after an edit asks first', (tester) async {
      await pump(tester, '/training/create-workout');
      await openNew(tester);
      await pick(tester, ['Aa Press']);
      await tester.tap(find.text('Aa Press'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('SetTarget.close')));
      await tester.pumpAndSettle();
      expect(find.text('Targets'), findsNothing);

      await tester.tap(find.text('Aa Press'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('SetTarget.addSet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('SetTarget.close')));
      await tester.pumpAndSettle();
      expect(find.text('Discard Changes?'), findsOneWidget);
      await tester.tap(find.text('Discard Changes'));
      await tester.pumpAndSettle();
      expect(find.text('Targets'), findsNothing);
      expect(find.text('1 set · 8–12'), findsOneWidget);
    });

    testWidgets('substitutions are picked, never the exercise itself', (
      tester,
    ) async {
      await pump(tester, '/training/create-workout');
      await openNew(tester);
      await pick(tester, ['Aa Press']);
      await tester.tap(find.text('Aa Press'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('SetTarget.addSubstitution')));
      await tester.pumpAndSettle();
      await pick(tester, ['Ab Row']);
      expect(find.text('Ab Row'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Ab Row'), findsNothing);
    });
  });

  group("a mesocycle's day", () {
    testWidgets('gets exercises, which make it a workout to save', (
      tester,
    ) async {
      final (world, _) = await pump(tester, '/training/create-mesocycle');
      await tester.enterText(
        find.byKey(const Key('NameProgram.name')),
        'Block',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('NameProgram.continue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ProgramIcon.continue')));
      await tester.pumpAndSettle();

      // A rest day: the picker does not open on its own.
      expect(
        find.text('Add exercises to turn this rest day into a workout day.'),
        findsOneWidget,
      );
      expect(find.text('Select at least one exercise'), findsNothing);

      await tester.tap(find.byKey(const Key('DefineWorkout.addExercise')));
      await tester.pumpAndSettle();
      await pick(tester, ['Aa Press']);
      expect(find.text('Workout A'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ProgramDesign.activate')));
      await tester.pumpAndSettle();
      final saved = (await tester.runAsync(
        () => world.programs.watchMesocycles(programUid).first,
      ))!.firstWhere((m) => m.name == 'Block');
      expect(
        saved.workoutTemplates.single.exercises.single.exercise.id,
        'aa-press',
      );
      expect(
        (await tester.runAsync(() => world.users.watchUser(programUid).first))!
            .submittedActiveMesocycleId,
        saved.id,
      );
    });
  });
}
