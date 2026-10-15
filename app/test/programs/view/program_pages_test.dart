import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/notifications/notification_copy.dart';
import 'package:compound/programs/programs.dart';
import 'package:compound/training/training.dart';
import 'package:compound/training_library/training_library.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart';

import '../../helpers/helpers.dart';
import '../helpers.dart';

/// The Training tab with the program routes, and Today's card on its own.
GoRouter _router(String location) => GoRouter(
  initialLocation: location,
  routes: [
    GoRoute(
      path: '/today',
      builder: (_, _) =>
          Scaffold(body: ListView(children: const [TodaysWorkoutCard()])),
    ),
    GoRoute(
      path: '/training',
      builder: (_, _) => const TrainingPage(),
      routes: [
        ...programRoutes,
        GoRoute(
          path: WorkoutsPage.path,
          name: WorkoutsPage.name,
          builder: (_, _) => const Text('Workouts screen'),
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
        ),
        GoRoute(
          path: 'history',
          name: 'workoutHistory',
          builder: (_, _) => const Text('History screen'),
          routes: [
            GoRoute(
              path: WorkoutSessionDetailPage.path,
              name: WorkoutSessionDetailPage.name,
              builder: (_, state) =>
                  Text('Session ${state.pathParameters.values.single}'),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: WorkoutTrackerPage.path,
      name: WorkoutTrackerPage.name,
      builder: (_, _) => const Text('Tracker screen'),
    ),
  ],
);

/// [read] outside the fake clock, which a repository stream's first value
/// would otherwise wait on.
Future<T> _read<T>(WidgetTester tester, Future<T> Function() read) async =>
    (await tester.runAsync(read)) as T;

void main() {
  late AppBloc appBloc;
  final m1 = programMesocycle('m1');
  final m2 = programMesocycle('m2', cycles: 3);
  final yesterday = programNow.subtract(const Duration(hours: 20));

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(AuthUser(uid: programUid, isAnonymous: false)),
    );
  });

  Future<ProgramWorld> pump(
    WidgetTester tester,
    String location, {
    List<Macrocycle>? macrocycles,
    List<WorkoutSessionModel> history = const [],
    String? active = 'm1',
  }) async {
    tester.view
      ..physicalSize = const Size(1200, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final world = ProgramWorld.seeded(
      mesocycles: [m1, m2],
      macrocycles:
          macrocycles ??
          [
            programMacrocycle('p', ['m1']),
          ],
      history: history,
      active: active,
    );
    final programs = world.cubit()..userChanged(programUid);
    final workout = ActiveWorkoutCubit(
      sessions: world.sessions,
      users: world.users,
      library: InMemoryTrainingLibraryRepository(),
      analytics: world.analytics,
      store: InMemoryActiveSessionStore(),
      notifications: FakeNotificationsRepository(),
      copy: AppNotificationCopy(
        () => lookupAppLocalizations(const Locale('en')),
      ),
    );
    unawaited(workout.userChanged(programUid));
    await tester.pumpApp(
      const SizedBox(),
      appBloc: appBloc,
      router: _router(location),
      programRepository: world.programs,
      userRepository: world.users,
      workoutSessionRepository: world.sessions,
      analyticsRepository: world.analytics,
      programsCubit: programs,
      activeWorkoutCubit: workout,
    );
    await tester.pumpAndSettle();
    return world;
  }

  group('Training', () {
    testWidgets('shows the active mesocycle and its microcycle', (
      tester,
    ) async {
      await pump(
        tester,
        '/training',
        history: [programSession('upper', yesterday, id: 'done')],
      );
      expect(find.text('Active Mesocycle'), findsOneWidget);
      expect(find.text('Block m1'), findsOneWidget);
      expect(find.text('Micro 1/2'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Macrocycles'), findsOneWidget);
      expect(find.text('Mesocycles'), findsOneWidget);

      // A finished day opens its session.
      await tester.tap(find.text('Upper'));
      await tester.pumpAndSettle();
      expect(find.text('Session done'), findsOneWidget);
    });

    testWidgets('picks another microcycle, and a day there is a preview', (
      tester,
    ) async {
      await pump(tester, '/training');
      await tester.tap(find.text('Micro 1/2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Microcycle 2').last, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Micro 2/2'), findsOneWidget);

      await tester.tap(find.text('Lower'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutTemplateDetailPage), findsOneWidget);
      expect(find.text('Start Workout'), findsNothing);
    });

    testWidgets('ticks a rest day and skips a workout', (tester) async {
      final world = await pump(tester, '/training');
      await tester.tap(find.text('Rest Day'));
      await tester.pumpAndSettle();
      expect(
        (await _read(
          tester,
          () => world.sessions.watchSessions(programUid).first,
        )).single.isRestDay,
        isTrue,
      );

      await tester.longPress(find.text('Upper'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip').last);
      await tester.pumpAndSettle();
      final plan = (await _read(
        tester,
        () => world.programs.watchMacrocycles(programUid).first,
      )).single;
      expect(plan.skips.single.templateId, 'upper');
    });

    testWidgets('deletes the active mesocycle after asking', (tester) async {
      final world = await pump(tester, '/training');
      await tester.tap(find.byTooltip('Workout options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Mesocycle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        [
          for (final m in await _read(
            tester,
            () => world.programs.watchMesocycles(programUid).first,
          ))
            m.id,
        ],
        ['m2'],
      );
      expect(find.text('No Active Mesocycle'), findsOneWidget);
      await tester.tap(find.text('Choose Mesocycle'));
      await tester.pumpAndSettle();
      expect(find.byType(MesocycleLibraryPage), findsOneWidget);
    });
  });

  group(MesocycleLibraryPage, () {
    testWidgets('lists the active, saved and template mesocycles', (
      tester,
    ) async {
      final world = await pump(tester, '/training/mesocycles');
      expect(find.text('Saved Mesocycles'), findsOneWidget);
      expect(find.text('Templates'), findsOneWidget);
      expect(find.text('Push/Pull/Legs'), findsOneWidget);

      await tester.tap(find.text('Block m2'));
      await tester.pumpAndSettle();
      expect(find.text('Lower'), findsOneWidget);

      await tester.tap(find.byTooltip('Workout options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Mesocycle'));
      await tester.pumpAndSettle();
      expect(
        find.text("Delete 'Block m2'? This can't be undone."),
        findsOneWidget,
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        [
          for (final m in await _read(
            tester,
            () => world.programs.watchMesocycles(programUid).first,
          ))
            m.id,
        ],
        ['m1'],
      );
      expect(
        world.analytics.names,
        containsAll([
          'TrainingProgramLibraryView_Appear',
          'TrainingProgramLibraryView_DeleteProgram_Success',
        ]),
      );
    });

    testWidgets('a template starts as the active mesocycle', (tester) async {
      final world = await pump(tester, '/training/mesocycles');
      await tester.tap(find.text('Full Body'));
      await tester.pumpAndSettle();
      expect(find.byType(PrebuiltMesocycleDetailPage), findsOneWidget);
      expect(find.text('Days per microcycle'), findsOneWidget);

      await tester.tap(find.text('Start Mesocycle'));
      await tester.pumpAndSettle();
      expect(find.byType(PrebuiltMesocycleDetailPage), findsNothing);
      final user = await _read(
        tester,
        () => world.users.watchUser(programUid).first,
      );
      final mesocycles = await _read(
        tester,
        () => world.programs.watchMesocycles(programUid).first,
      );
      expect(
        mesocycles
            .firstWhere((m) => m.id == user!.submittedActiveMesocycleId)
            .name,
        'Full Body',
      );
    });

    testWidgets('an unknown template says so', (tester) async {
      await pump(tester, '/training/mesocycles/template/nope');
      expect(find.text('No Mesocycles'), findsOneWidget);
    });
  });

  group(MacrocyclesPage, () {
    testWidgets('lists the followed and saved, and makes a new one', (
      tester,
    ) async {
      final world = await pump(
        tester,
        '/training/macrocycles',
        macrocycles: [
          programMacrocycle('p', ['m1']),
          programMacrocycle('s', ['m1', 'm2'], status: MacrocycleStatus.ended),
        ],
      );
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('1 mesocycle · Mesocycle 1 of 1'), findsOneWidget);
      expect(find.text('2 mesocycles · Ended'), findsOneWidget);

      await tester.tap(find.byTooltip('New Macrocycle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block m2').last);
      await tester.pumpAndSettle();
      expect(find.text('Mesocycle 1'), findsOneWidget);
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(
        await _read(
          tester,
          () => world.programs.watchMacrocycles(programUid).first,
        ),
        hasLength(3),
      );
    });

    testWidgets('with none, offers a new one', (tester) async {
      await pump(tester, '/training/macrocycles', macrocycles: const []);
      expect(find.text('No Macrocycles'), findsOneWidget);
      await tester.tap(find.text('New Macrocycle'));
      await tester.pumpAndSettle();
      expect(find.byType(MacrocycleDetailPage), findsOneWidget);
    });
  });

  group(MacrocycleDetailPage, () {
    testWidgets('replacing the followed one asks first, then starts it', (
      tester,
    ) async {
      final world = await pump(
        tester,
        '/training/macrocycles/s',
        macrocycles: [
          programMacrocycle('p', ['m1']),
          programMacrocycle('s', [
            'm1',
            'm2',
          ], status: MacrocycleStatus.notStarted),
        ],
      );
      expect(find.text('Start At'), findsOneWidget);
      await tester.tap(find.text('1. Block m1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2. Block m2').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Macrocycle'));
      await tester.pumpAndSettle();
      expect(find.text('Replace Plan p?'), findsOneWidget);
      await tester.tap(find.text('Start Macrocycle').last);
      await tester.pumpAndSettle();

      final user = await _read(
        tester,
        () => world.users.watchUser(programUid).first,
      );
      expect(user!.submittedActiveMesocycleId, 'm2');
    });

    testWidgets('restarts the followed one, and deletes', (tester) async {
      final world = await pump(tester, '/training/macrocycles/p');
      expect(find.text('Restart Macrocycle'), findsOneWidget);
      await tester.tap(find.byIcon(AppSymbols.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Macrocycle'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Plan p?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        await _read(
          tester,
          () => world.programs.watchMacrocycles(programUid).first,
        ),
        isEmpty,
      );
    });
  });

  group(TodaysWorkoutCard, () {
    testWidgets('offers the next workout with its targets, and skips it', (
      tester,
    ) async {
      final world = await pump(tester, '/today');
      expect(find.text("Today's Workout"), findsOneWidget);
      expect(find.text('Upper'), findsOneWidget);
      expect(find.textContaining('Week 1 of 2 · Day 1'), findsOneWidget);
      expect(find.textContaining('Bench'), findsWidgets);

      await tester.tap(find.text('Skip Workout'));
      await tester.pumpAndSettle();
      expect(find.text('Skip Upper?'), findsOneWidget);
      await tester.tap(find.text('Skip').last);
      await tester.pumpAndSettle();
      expect(find.text('Lower'), findsOneWidget);
      expect(world.analytics.names, contains('TodaysWorkoutCard_Skip_Success'));
    });

    testWidgets("starts today's workout into the tracker", (tester) async {
      await pump(tester, '/today');
      await tester.tap(find.text('Start Workout'));
      await tester.pumpAndSettle();
      expect(find.text('Tracker screen'), findsOneWidget);
    });

    testWidgets('a rest day offers the next workout instead', (tester) async {
      await pump(
        tester,
        '/today',
        history: [
          programSession('upper', yesterday),
          programSession('rest', programNow, id: 'r', rest: true),
        ],
      );
      expect(find.text('Rest Day'), findsOneWidget);
      expect(find.text('Start Lower Instead'), findsOneWidget);
    });

    testWidgets('a finished workout shows what it came to', (tester) async {
      await pump(
        tester,
        '/today',
        history: [programSession('upper', programNow, id: 'done')],
      );
      expect(find.text('Upper'), findsOneWidget);
      expect(find.textContaining('0 sets'), findsOneWidget);
    });

    testWidgets('without a mesocycle, an empty workout or choosing one', (
      tester,
    ) async {
      await pump(tester, '/today', active: null);
      expect(find.text('No Active Mesocycle'), findsOneWidget);
      expect(find.text('Start Empty Workout'), findsOneWidget);
      await tester.tap(find.text('Choose Mesocycle'));
      await tester.pumpAndSettle();
      expect(find.byType(MesocycleLibraryPage), findsOneWidget);
    });

    testWidgets('a completed macrocycle offers a repeat', (tester) async {
      final world = await pump(
        tester,
        '/today',
        macrocycles: [
          programMacrocycle('p', ['m1'], status: MacrocycleStatus.completed),
        ],
        history: [
          for (var cycle = 0; cycle < 2; cycle++) ...[
            programSession(
              'upper',
              yesterday.add(Duration(minutes: cycle * 2)),
            ),
            programSession(
              'lower',
              yesterday.add(Duration(minutes: cycle * 2 + 1)),
            ),
          ],
        ],
      );
      expect(find.text('Plan p complete'), findsOneWidget);
      await tester.tap(find.text('Repeat Macrocycle'));
      await tester.pumpAndSettle();
      expect(
        (await _read(
          tester,
          () => world.programs.watchMacrocycles(programUid).first,
        )).single.status,
        MacrocycleStatus.active,
      );
    });
  });
}
