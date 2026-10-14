import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/workout_history/workout_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  const authUser = AuthUser(uid: 'friend', isAnonymous: false);
  late AppBloc appBloc;
  late WorkoutSessionRepository repository;

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(const AppAuthenticated(authUser));
    repository = MockWorkoutSessionRepository();
  });

  Future<void> pump(
    WidgetTester tester,
    Stream<List<WorkoutSessionModel>> sessions, {
    double textScale = 1,
  }) async {
    when(() => repository.watchSessions('friend')).thenAnswer((_) => sessions);
    await tester.pumpApp(
      const WorkoutHistoryPage(),
      appBloc: appBloc,
      workoutSessionRepository: repository,
      textScale: textScale,
    );
  }

  final before = fixtureSession(
    'a',
    exercises: [
      fixtureExercise('Bench', sets: [fixtureSet(weightKg: 90)]),
    ],
  );
  final recent = fixtureSession(
    'b',
    day: 4,
    weekStreakCount: 6,
    notes: '  Left shoulder twinged  ',
    exercises: [
      fixtureExercise(
        'Bench',
        sets: [
          fixtureSet(reps: 10, weightKg: 20, isWarmup: true),
          fixtureSet(),
          fixtureSet(),
        ],
      ),
      fixtureExercise('Skipped', sets: [fixtureSet(completed: false)]),
    ],
  );

  group(WorkoutHistoryPage, () {
    testWidgets('shows progress until the sessions arrive', (tester) async {
      await pump(tester, const Stream.empty());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('lists finished workouts with their totals and highlights', (
      tester,
    ) async {
      await pump(tester, Stream.value([before, recent]));
      await tester.pump();

      expect(find.text('Completed Workouts'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(find.text('Session b'), findsOneWidget);
      expect(find.text('Session a'), findsOneWidget);
      expect(find.text('PR: Bench 100 kg × 5'), findsOneWidget);
      expect(find.text('6-week streak'), findsOneWidget);
      expect(find.text('2nd workout of the week'), findsOneWidget);
      expect(find.text('1.0 t'), findsOneWidget);
      expect(find.text('1:00:00'), findsNWidgets(2));
      expect(find.text('2 × 5 @ 100 kg'), findsOneWidget);
      expect(find.text('Skipped'), findsNothing);
      expect(find.text('Left shoulder twinged'), findsOneWidget);
    });

    testWidgets('stacks the exercise lines at the largest text sizes', (
      tester,
    ) async {
      await pump(tester, Stream.value([recent]), textScale: 2);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Bench'), findsOneWidget);
    });

    testWidgets('says when there are none', (tester) async {
      await pump(tester, Stream.value(const []));
      await tester.pump();

      expect(find.text('No Workout History'), findsOneWidget);
      expect(
        find.text('Complete your first workout to see it here.'),
        findsOneWidget,
      );
    });

    testWidgets('says when they cannot be read, and tries again', (
      tester,
    ) async {
      var calls = 0;
      when(() => repository.watchSessions('friend')).thenAnswer(
        (_) => calls++ == 0
            ? Stream.error(Exception('offline'))
            : Stream.value(const []),
      );
      await tester.pumpApp(
        const WorkoutHistoryPage(),
        appBloc: appBloc,
        workoutSessionRepository: repository,
      );
      await tester.pump();
      expect(find.text("Your workouts couldn't be loaded."), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();
      await tester.pump();
      expect(find.text('No Workout History'), findsOneWidget);
    });

    testWidgets('shows nothing once signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(const WorkoutHistoryPage(), appBloc: appBloc);
      expect(find.byType(WorkoutHistoryView), findsNothing);
    });
  });
}
