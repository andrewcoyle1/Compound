@Timeout(Duration(seconds: 30))
library;

import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

/// A clock the test moves by hand, for the cubit and the screen alike.
class _Clock {
  DateTime now = DateTime(2026, 10, 15, 18);

  DateTime call() => now;
}

const String uid = sampleUserId;

AppBloc authenticatedAppBloc(String uid) {
  final appBloc = MockAppBloc();
  when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => appBloc.state)
      .thenReturn(AppAuthenticated(AuthUser(uid: uid, isAnonymous: false)));
  return appBloc;
}

void main() {
  late _Clock clock;
  late InMemoryWorkoutSessionRepository sessions;
  late InMemoryUserRepository users;
  late ActiveWorkoutCubit cubit;

  setUp(() {
    clock = _Clock();
    sessions = InMemoryWorkoutSessionRepository(sessions: const []);
    users = InMemoryUserRepository(users: {uid: sampleUser(now: clock.now)});
    cubit = ActiveWorkoutCubit(
      sessions: sessions,
      users: users,
      library: InMemoryTrainingLibraryRepository(
        workoutSettings: const [
          WorkoutSettings(
            authorId: uid,
            addSmartWarmUps: false,
            rirTracking: true,
          ),
        ],
      ),
      analytics: const AnalyticsRepository(),
      store: InMemoryActiveSessionStore(),
      clock: clock.call,
      wait: (_) async {},
    );
  });

  /// Starts My Upper Body with every set at 60 kg × 8.
  Future<void> start(WidgetTester tester) async {
    await cubit.userChanged(uid);
    await cubit.start(
      template: sampleUserWorkoutTemplates.first,
      eventPrefix: 'x',
    );
    for (final exercise in cubit.state.session!.exercises) {
      for (final set in exercise.sets) {
        cubit
          ..openKeypad(set.id, SetField.weight)
          ..keypadKey('6')
          ..keypadKey('0')
          ..keypadNext()
          ..keypadKey('8')
          ..closeKeypad();
      }
    }
  }

  String nextSetId() => (cubit.state.primaryAction! as r.LogSetAction).setId;

  Future<void> pump(WidgetTester tester, {double textScale = 1}) async {
    final router = GoRouter(
      initialLocation: WorkoutTrackerPage.path,
      routes: [
        GoRoute(path: '/today', builder: (_, _) => const Text('Today')),
        GoRoute(
          path: WorkoutTrackerPage.path,
          name: WorkoutTrackerPage.name,
          builder: (_, _) => const WorkoutTrackerPage(),
        ),
        GoRoute(
          path: WorkoutSessionDetailPage.summaryPath,
          name: WorkoutSessionDetailPage.summaryName,
          builder: (_, state) => WorkoutSessionDetailPage(
            sessionId: state.pathParameters['sessionId']!,
            session: state.extra as WorkoutSessionModel?,
            isWorkoutSummary: true,
          ),
        ),
      ],
    );
    await tester.pumpApp(
      RepositoryProvider.value(
        value: TrackerClock(clock.call),
        child: BlocProvider.value(
          value: cubit,
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: Router.withConfig(config: router),
          ),
        ),
      ),
      userRepository: users,
      workoutSessionRepository: sessions,
      appBloc: authenticatedAppBloc(uid),
    );
    await tester.pumpAndSettle();
  }

  group(WorkoutTrackerPage, () {
    testWidgets('the log button logs the next set', (tester) async {
      await start(tester);
      await pump(tester);
      final setId = nextSetId();

      expect(find.text('Log set 1 · 60 kg × 8'), findsOneWidget);
      await tester.tap(find.text('Log set 1 · 60 kg × 8'));
      await tester.pumpAndSettle();

      expect(cubit.state.set(setId)!.completedAt, clock.now);
      expect(find.textContaining('Skip Rest'), findsOneWidget);
      expect(find.text('+15s'), findsOneWidget);
      expect(find.text('Set 1 · 60 kg × 8'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('the correction bar corrects the set just logged', (
      tester,
    ) async {
      await start(tester);
      await pump(tester);
      final setId = nextSetId();
      await tester.tap(find.byKey(ValueKey('done-$setId')));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add a rep'));
      await tester.pumpAndSettle();
      expect(cubit.state.set(setId)!.reps, 9);
      await tester.tap(find.byTooltip('Remove a rep'));
      await tester.pumpAndSettle();
      expect(cubit.state.set(setId)!.reps, 8);

      await tester.tap(find.bySemanticsLabel('2 reps in reserve'));
      await tester.pumpAndSettle();
      expect(cubit.state.set(setId)!.rpe, 8);

      // The reps taps undo as one, then the log.
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(cubit.state.set(setId)!.completedAt, isNotNull);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(cubit.state.set(setId)!.completedAt, isNull);
      expect(find.text('Undo'), findsNothing);
      await cubit.close();
    });

    testWidgets('+15s adds rest, and Skip Rest ends it', (tester) async {
      await start(tester);
      await pump(tester);
      await tester.tap(find.byKey(ValueKey('done-${nextSetId()}')));
      await tester.pumpAndSettle();
      final end = cubit.state.restEnd!;

      await tester.tap(find.text('+15s'));
      await tester.pump();
      expect(cubit.state.restEnd, end.add(const Duration(seconds: 15)));

      clock.now = clock.now.add(const Duration(seconds: 1));
      await tester.tap(find.textContaining('Skip Rest'));
      await tester.pumpAndSettle();
      expect(cubit.state.restEnd, isNull);
      await cubit.close();
    });

    testWidgets('the keypad types a set and refuses one with no reps', (
      tester,
    ) async {
      await start(tester);
      await pump(tester);
      final setId = nextSetId();
      await tester.tap(find.byKey(ValueKey('cell-$setId-reps')));
      await tester.pumpAndSettle();
      expect(find.text('RIR'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('keypad-delete')));
      await tester.tap(find.byKey(const ValueKey('keypad-done')));
      await tester.pumpAndSettle();

      expect(find.text('Unable to Log Set'), findsOneWidget);
      expect(find.text('Enter at least one rep.'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('keypad-1')));
      await tester.tap(find.byKey(const ValueKey('keypad-2')));
      await tester.tap(find.bySemanticsLabel('1 reps in reserve'));
      await tester.tap(find.byKey(const ValueKey('keypad-done')));
      await tester.pumpAndSettle();
      final set = cubit.state.set(setId)!;
      expect(set.reps, 12);
      expect(set.rpe, 9);
      expect(set.completedAt, isNotNull);
      expect(find.byKey(const ValueKey('keypad-done')), findsNothing);
      await cubit.close();
    });

    testWidgets('finishing opens the summary of the saved workout', (
      tester,
    ) async {
      await start(tester);
      await pump(tester);
      await tester.tap(find.byKey(ValueKey('done-${nextSetId()}')));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Workout options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish Workout…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkoutTrackerView), findsNothing);
      expect(find.text('Done'), findsOneWidget);
      final saved = await sessions.watchSessions(uid).first;
      expect(saved.single.exercises.expand((e) => e.sets), hasLength(1));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('finishing with nothing logged asks first', (tester) async {
      await start(tester);
      await pump(tester);
      await tester.tap(find.byTooltip('Workout options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish Workout…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      expect(find.text('No Sets Logged'), findsOneWidget);
      await tester.tap(find.text('Discard Workout'));
      await tester.pumpAndSettle();
      expect(cubit.state.isActive, isFalse);
      expect(find.text('Today'), findsOneWidget);
      expect(await sessions.watchSessions(uid).first, isEmpty);
      await cubit.close();
    });

    testWidgets('pauses from the menu; the button resumes', (tester) async {
      await start(tester);
      await pump(tester);
      await tester.tap(find.byTooltip('Workout options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause Workout'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Paused'), findsOneWidget);
      // Past the moment a tap on the changed button is dropped.
      clock.now = clock.now.add(const Duration(seconds: 1));
      await tester.tap(find.text('Resume Workout'));
      await tester.pumpAndSettle();
      expect(cubit.state.isPaused, isFalse);
      await cubit.close();
    });

    testWidgets('lays out at the largest text size', (tester) async {
      await start(tester);
      await pump(tester, textScale: 2);
      expect(tester.takeException(), isNull);
      // The figures give way on the button; the row shows them.
      expect(find.text('Log set 1'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('with no workout, says so', (tester) async {
      await cubit.userChanged(uid);
      await pump(tester);
      expect(find.text('No Workout in Progress'), findsOneWidget);
      await cubit.close();
    });
  });

  group('startWorkout', () {
    testWidgets('asks before replacing the workout under way', (tester) async {
      await start(tester);
      final first = cubit.state.session!.id;
      await tester.pumpApp(
        RepositoryProvider.value(
          value: TrackerClock(clock.call),
          child: BlocProvider.value(
            value: cubit,
            child: Router.withConfig(
              config: GoRouter(
                initialLocation: '/start',
                routes: [
                  GoRoute(
                    path: '/start',
                    builder: (context, _) => TextButton(
                      onPressed: () => startWorkout(context, eventPrefix: 'x'),
                      child: const Text('Start'),
                    ),
                  ),
                  GoRoute(
                    path: WorkoutTrackerPage.path,
                    name: WorkoutTrackerPage.name,
                    builder: (_, _) => const Text('Tracker'),
                  ),
                ],
              ),
            ),
          ),
        ),
        appBloc: authenticatedAppBloc(uid),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.text('Active Workout'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cubit.state.session!.id, first);

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard & Start New'));
      await tester.pumpAndSettle();
      expect(cubit.state.session!.id, isNot(first));
      expect(cubit.state.session!.exercises, isEmpty);
      expect(find.text('Tracker'), findsOneWidget);
      await cubit.close();
    });
  });
}
