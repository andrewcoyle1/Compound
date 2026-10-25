import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/app/app.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:compound_models/compound_models.dart'
    show WorkoutSessionModel, WorkoutSessionModelKeys;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

class _MockCircleBloc extends MockBloc<CircleEvent, CircleState>
    implements CircleBloc;

void main() {
  const authUser = AuthUser(uid: 'friend', isAnonymous: false);
  late AppBloc appBloc;
  late WorkoutSessionRepository sessions;
  late UserRepository users;

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(const AppAuthenticated(authUser));
    sessions = MockWorkoutSessionRepository();
    when(() => sessions.watchSessions('friend'))
        .thenAnswer((_) => const Stream.empty());
    users = MockUserRepository();
    when(() => users.watchUser('friend')).thenAnswer(
      (_) => Stream.value(
        const UserModel(
          userId: 'friend',
          submittedWeightUnitPreference: WeightUnitPreference.pounds,
        ),
      ),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    double textScale = 1,
    AnalyticsRecorder? analytics,
    LinkRecorder? links,
  }) async {
    await tester.pumpApp(
      const WorkoutSessionDetailPage(sessionId: 's'),
      analyticsRepository: analytics ?? AnalyticsRecorder(),
      linkOpener: links ?? LinkRecorder(),
      appBloc: appBloc,
      userRepository: users,
      workoutSessionRepository: sessions,
      textScale: textScale,
    );
    await tester.pump();
  }

  final session = fixtureSession(
    's',
    minutes: 64,
    notes: 'Felt strong',
    exercises: [
      fixtureExercise(
        'Bench',
        notes: 'Pause the first rep',
        sets: [
          fixtureSet(reps: 10, weightKg: 40, isWarmup: true),
          fixtureSet(reps: 8, weightKg: 80, rpe: 7.5),
          fixtureSet(id: 'parent', reps: 8, weightKg: 80, rpe: 9),
          fixtureSet(
            reps: 6,
            weightKg: 60,
            kind: 'drop',
            parentSetId: 'parent',
          ),
        ],
      ),
      fixtureExercise(
        'Split Squat',
        sets: [
          fixtureSet(reps: 10, weightKg: 20, side: 'left'),
          fixtureSet(reps: 10, weightKg: 20, side: 'right'),
        ],
        weightUnit: ExerciseWeightUnit.pounds,
      ),
    ],
  );

  group(WorkoutSessionDetailPage, () {
    testWidgets('shows progress while reading', (tester) async {
      when(() => sessions.session('friend', 's'))
          .thenAnswer((_) => Future.delayed(const Duration(seconds: 1)));
      await tester.pumpApp(
        const WorkoutSessionDetailPage(sessionId: 's'),
        appBloc: appBloc,
        workoutSessionRepository: sessions,
      );
      expect(find.byType(AppSpinner), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('shows the workout, its exercises and sets', (tester) async {
      when(() => sessions.session('friend', 's'))
          .thenAnswer((_) async => session);
      await pump(tester);

      expect(find.widgetWithText(AppBar, 'Session s'), findsOneWidget);
      expect(find.text('Workout Details'), findsOneWidget);
      expect(find.text('1:04:00'), findsOneWidget);
      // 2 × 8 × 80 + 6 × 60 + 2 × 10 × 20 kg = 2,040 kg, in the user's
      // pounds: the hero, which a past workout only shows.
      expect(find.text('4,497\u00a0lb'), findsOneWidget);
      expect(find.text('VOLUME'), findsOneWidget);
      expect(find.text('Workout Complete'), findsNothing);
      expect(find.text('1h 4m'), findsOneWidget);
      expect(find.text('Felt strong'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Exercise Details'), 100);
      expect(find.text('Exercise Details'), findsOneWidget);
      expect(find.text('2 sets · 1,640\u00a0kg volume'), findsOneWidget);
      // Each exercise opens onto its note and sets, as Swift's disclosure.
      expect(find.text('Pause the first rep'), findsNothing);
      for (final name in ['Split Squat', 'Bench']) {
        await tester.ensureVisible(find.text(name));
        await tester.pumpAndSettle();
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Pause the first rep'));
      expect(find.text('Pause the first rep'), findsOneWidget);
      expect(find.text('Warm-up'), findsOneWidget);
      expect(find.text('40\u00a0kg × 10 reps'), findsOneWidget);
      expect(find.text('Set 1'), findsOneWidget);
      expect(find.text('Set 2'), findsOneWidget);
      expect(find.text('RPE 7.5'), findsOneWidget);
      expect(find.text('Drop set'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Set 1R'), 100);
      expect(find.text('Set 1L'), findsOneWidget);
      expect(find.text('1 set · 881.8\u00a0lb volume'), findsOneWidget);
      expect(find.text('44.1\u00a0lb × 10 reps'), findsNWidgets(2));
    });

    group('confetti', () {
      final burst = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'ConfettiWidget',
      );

      testWidgets('bursts once as the summary of a workout opens', (
        tester,
      ) async {
        when(() => sessions.session('friend', 's'))
            .thenAnswer((_) async => session);
        await tester.pumpApp(
          WorkoutSessionDetailPage(
            sessionId: 's',
            session: session,
            isWorkoutSummary: true,
          ),
          appBloc: appBloc,
          userRepository: users,
          workoutSessionRepository: sessions,
          disableAnimations: false,
        );
        await tester.pump();
        await tester.pump();
        expect(burst, findsOneWidget);
        expect(find.text('Workout Complete'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(burst, findsNothing);
        expect(find.text('4,497\u00a0lb'), findsOneWidget);
      });

      testWidgets('stays still for a past workout', (tester) async {
        when(() => sessions.session('friend', 's'))
            .thenAnswer((_) async => session);
        await pump(tester);
        await tester.pump();
        expect(burst, findsNothing);
      });
    });

    testWidgets('leads the summary with a personal record, and lists them', (
      tester,
    ) async {
      final haptics = <AppHaptic>[];
      AppHaptics.debugPlay = haptics.add;
      addTearDown(() => AppHaptics.debugPlay = null);
      final earlier = fixtureSession(
        'e',
        day: 1,
        exercises: [
          fixtureExercise('Bench', sets: [fixtureSet(reps: 8, weightKg: 70)]),
        ],
      );
      when(() => sessions.session('friend', 's'))
          .thenAnswer((_) async => session);
      final circle = _MockCircleBloc();
      when(() => circle.state)
          .thenReturn(CircleState(ownSessions: [earlier, session]));
      await tester.pumpApp(
        WorkoutSessionDetailPage(
          sessionId: 's',
          session: session,
          isWorkoutSummary: true,
        ),
        appBloc: appBloc,
        userRepository: users,
        workoutSessionRepository: sessions,
        circleBloc: circle,
      );
      await tester.pumpAndSettle();

      expect(find.text('New PR'), findsOneWidget);
      expect(find.text('BENCH'), findsOneWidget);
      // The heaviest set beat 70 kg, in the author's kilograms.
      expect(find.text('80\u00a0kg × 8'), findsOneWidget);
      // The volume is not the hero, so its row stays.
      expect(find.text('Volume'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Personal Records'), 100);
      expect(find.text('80\u00a0kg × 8'), findsNWidgets(2));
      expect(haptics, [AppHaptic.success]);
    });

    testWidgets('links a workout on Strava for its author', (tester) async {
      final stored = WorkoutSessionModel.fromFirestore({
        ...session.toFirestore(),
        WorkoutSessionModelKeys.stravaActivityId: 99,
      });
      when(() => sessions.session('friend', 's'))
          .thenAnswer((_) async => session);
      when(() => sessions.watchSessions('friend'))
          .thenAnswer((_) => Stream.value([stored]));
      final analytics = AnalyticsRecorder();
      final links = LinkRecorder();
      await pump(tester, analytics: analytics, links: links);
      await tester.pump();

      await tester.ensureVisible(find.text('View on Strava'));
      await tester.pump();
      await tester.tap(find.text('View on Strava'));

      expect(links.opened, [Uri.parse('https://www.strava.com/activities/99')]);
      expect(analytics.parameters('WorkoutSessionDetailView_ViewOnStrava'), {
        'session_id': 's',
      });
    });

    testWidgets('shows a placeholder volume and fits the largest text', (
      tester,
    ) async {
      when(() => sessions.session('friend', 's')).thenAnswer(
        (_) async => fixtureSession(
          's',
          exercises: [
            fixtureExercise(
              'Plank',
              mode: TrackingMode.timeOnly,
              sets: [fixtureSet(reps: null, weightKg: null, durationSec: 60)],
            ),
          ],
        ),
      );
      await pump(tester, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.text('—'), findsOneWidget);
      // The author's own finished workout: Ask Coach, above the sets.
      expect(find.text('Ask Coach About This Workout'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Plank'), 200);
      await tester.ensureVisible(find.text('Plank'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plank'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('1:00'), 200);
      expect(find.text('1:00'), findsOneWidget);
    });

    testWidgets('says when the workout is gone', (tester) async {
      when(() => sessions.session('friend', 's')).thenAnswer((_) async => null);
      await pump(tester);

      expect(find.text("This workout couldn't be found."), findsOneWidget);
      expect(find.text('Try Again'), findsNothing);
    });

    testWidgets('says when it cannot be read, and tries again', (tester) async {
      var calls = 0;
      when(() => sessions.session('friend', 's')).thenAnswer(
        (_) async => calls++ == 0 ? throw Exception('offline') : session,
      );
      await pump(tester);
      expect(find.text("This workout couldn't be loaded."), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Workout Details'), findsOneWidget);
    });

    testWidgets('shows nothing once signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(
        const WorkoutSessionDetailPage(sessionId: 's'),
        appBloc: appBloc,
      );
      expect(find.byType(WorkoutSessionDetailView), findsNothing);
    });
  });
}
