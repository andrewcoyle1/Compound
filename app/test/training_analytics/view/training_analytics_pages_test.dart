import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/progress/view/card_charts.dart';
import 'package:compound/training_analytics/training_analytics.dart';
import 'package:compound/training_analytics/training_analytics_routes.dart';
import 'package:compound/training_library/training_library.dart';
import 'package:compound_models/compound_models.dart' show ExerciseModelKeys;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  const uid = 'me';
  final today = DateTime.now();

  late AppBloc appBloc;

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(AuthUser(uid: uid, isAnonymous: false)),
    );
  });

  // The user's own exercise, so the library lists it.
  final press = ExerciseModel.fromFirestore({
    ...fixtureLibraryExercise(
      'press',
      name: 'Press',
      muscles: const {
        Muscles.sideDelts: MuscleTargetType.primary,
        Muscles.triceps: MuscleTargetType.secondary,
      },
    ).toFirestore(),
    ExerciseModelKeys.authorId: uid,
  });

  /// Press [daysAgo], heavier each session, in kilograms.
  WorkoutSessionModel lift(int daysAgo, double kg) {
    final day = DateTime(today.year, today.month, today.day - daysAgo, 9);
    return WorkoutSessionModel(
      id: 'press-$daysAgo',
      authorId: uid,
      name: 'Shoulders',
      dateCreated: day,
      dateModified: day,
      endedAt: day.add(const Duration(hours: 1)),
      exercises: [
        fixtureExercise(
          'press',
          sets: [for (var i = 0; i < 4; i++) fixtureSet(weightKg: kg, rpe: 8)],
        ),
      ],
    );
  }

  final history = [
    for (var week = 0; week < 4; week++) lift(1 + 7 * week, 100 - 5.0 * week),
  ];

  GoRouter router(String location) => GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/progress',
        builder: (_, _) => const Text('Progress tab'),
        routes: trainingAnalyticsRoutes,
      ),
      GoRoute(
        path: '/training/workouts',
        name: WorkoutsPage.name,
        builder: (_, _) => const Text('Workouts list'),
      ),
    ],
  );

  Future<void> pump(
    WidgetTester tester,
    String location, {
    List<WorkoutSessionModel>? sessions,
    WorkoutSessionRepository? workoutSessionRepository,
  }) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpApp(
      const SizedBox(),
      router: router(location),
      appBloc: appBloc,
      workoutSessionRepository:
          workoutSessionRepository ??
          InMemoryWorkoutSessionRepository(sessions: sessions ?? history),
      trainingLibraryRepository: InMemoryTrainingLibraryRepository(
        exercises: [press],
      ),
      userRepository: InMemoryUserRepository(
        users: {uid: const UserModel(userId: uid)},
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Exercises', () {
    testWidgets('lists every exercise and opens one', (tester) async {
      await pump(tester, '/progress/exercises');

      expect(find.text('Exercises'), findsWidgets);
      final card = find.ancestor(
        of: find.text('Press'),
        matching: find.byType(ExerciseOneRepMaxCard),
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      // 100 kg × (1 + (5 + 2) / 30).
      expect(
        find.descendant(of: card, matching: find.text('123.3')),
        findsOneWidget,
      );
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.text('Press'), findsWidgets);
      expect(find.text('Latest: Yesterday'), findsOneWidget);
      await tester.tap(find.text('Show All Data'));
      await tester.pumpAndSettle();
      expect(find.text('All Recorded Data'), findsOneWidget);
      expect(find.text('123.3 kg'), findsOneWidget);
    });

    testWidgets('an exercise never done offers a workout', (tester) async {
      await pump(tester, '/progress/exercises/system-barbell-squat');

      expect(find.text('No 1-RM data for Barbell Squat'), findsOneWidget);
      await tester.tap(find.text('Start Workout'));
      await tester.pumpAndSettle();
      expect(find.text('Workouts list'), findsOneWidget);
    });

    testWidgets('says so when the sessions cannot be read', (tester) async {
      final failing = MockWorkoutSessionRepository();
      when(() => failing.watchSessions(uid))
          .thenAnswer((_) => Stream.error(Exception('offline')));
      await pump(
        tester,
        '/progress/exercises',
        workoutSessionRepository: failing,
      );
      expect(find.text("Your training couldn't be loaded."), findsOneWidget);
    });
  });

  group('Muscle Groups', () {
    testWidgets('shows both regions and opens a muscle', (tester) async {
      await pump(tester, '/progress/muscles');

      expect(find.text('Upper'), findsOneWidget);
      expect(find.text('Lower'), findsOneWidget);
      expect(find.byType(MuscleSetsCard), findsNWidgets(Muscles.values.length));
      final card = find.ancestor(
        of: find.text('Side Delts'),
        matching: find.byType(MuscleSetsCard),
      );
      expect(find.descendant(of: card, matching: find.text('4')), findsOne);
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.text('Side Delts'), findsWidgets);
      expect(find.text('Adjusts Based on Your Progress'), findsOneWidget);
      // Rising lifts: keep the volume.
      expect(find.text('Keep your current sets'), findsOneWidget);
      expect(find.text('Strength trend'), findsOneWidget);
      await tester.tap(find.text('Show All Data'));
      await tester.pumpAndSettle();
      expect(find.text('4 sets'), findsNWidgets(4));
    });

    testWidgets('picks a range on the chart', (tester) async {
      await pump(tester, '/progress/muscles/triceps');
      await tester.tap(find.text('6M'));
      await tester.pumpAndSettle();
      expect(find.text('Daily Average'.toUpperCase()), findsOneWidget);
      expect(find.text('2 sets'), findsWidgets);
    });

    testWidgets('an unknown muscle shows them all', (tester) async {
      await pump(tester, '/progress/muscles/wings');
      expect(find.text('Upper'), findsOneWidget);
    });

    testWidgets('a muscle never trained offers a workout', (tester) async {
      await pump(tester, '/progress/muscles/calves');
      expect(
        find.text('No sets for Calves in recent workouts'),
        findsOneWidget,
      );
    });

    testWidgets('opens Muscle Balance and toggles a trend', (tester) async {
      await pump(tester, '/progress/muscles');
      await tester.tap(find.byTooltip('Muscle Balance'));
      await tester.pumpAndSettle();

      expect(find.text('Side Delts · Maintaining'), findsOneWidget);
      expect(find.text('Chest · Below maintenance'), findsOneWidget);
      expect(find.byType(Sparkline), findsNothing);
      await tester.tap(find.text('Side Delts · Maintaining'));
      await tester.pumpAndSettle();
      expect(find.text('Side Delts · last 12 weeks'), findsOneWidget);
      expect(
        find.text('Enough to keep muscle; 10–20 sets a week builds more.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Side Delts · Maintaining'));
      await tester.pumpAndSettle();
      expect(find.byType(Sparkline), findsNothing);
    });

    testWidgets('a lower-body trend shows in its own region', (tester) async {
      await pump(tester, '/progress/muscle-balance');
      await tester.tap(find.text('Quads · Below maintenance'));
      await tester.pumpAndSettle();
      expect(find.text('Quads · last 12 weeks'), findsOneWidget);
    });
  });

  group('Workouts', () {
    testWidgets('charts each workout and lists them', (tester) async {
      await pump(tester, '/progress/workouts');

      expect(find.text('Workouts'), findsOneWidget);
      await tester.tap(find.text('Show All Data'));
      await tester.pumpAndSettle();
      expect(find.text('4 sets · 2.0 t'), findsOneWidget);
    });

    testWidgets('the consistency grid opens every workout', (tester) async {
      await pump(tester, '/progress/workout-consistency');

      expect(find.byType(ContributionGrid), findsOneWidget);
      expect(find.bySemanticsLabel('4 workouts'), findsOneWidget);
      await tester.tap(find.text('Show All Data'));
      await tester.pumpAndSettle();
      expect(find.text('All Recorded Data'), findsOneWidget);
    });

    testWidgets('with none logged, both offer a workout', (tester) async {
      await pump(tester, '/progress/workout-consistency', sessions: const []);
      expect(find.text('No completed workouts'), findsOneWidget);
      await pump(tester, '/progress/workouts', sessions: const []);
      expect(find.text('No completed workouts'), findsOneWidget);
    });

    testWidgets('the grid lists a workout on its data page', (tester) async {
      await pump(tester, '/progress/workout-consistency/data');
      expect(find.text('4 sets · 2.0 t'), findsOneWidget);
    });
  });

  testWidgets('shows nothing while signed out', (tester) async {
    when(() => appBloc.state).thenReturn(const AppUnauthenticated());
    await tester.pumpApp(const MuscleGroupsPage(), appBloc: appBloc);
    expect(find.byType(MuscleGroupsView), findsNothing);
  });
}
