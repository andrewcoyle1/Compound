import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/training/training.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';
import '../../programs/helpers.dart';
import '../logic/training_calendar_test.dart' show trainingSession;

class _MockGoRouter extends Mock implements GoRouter;

void main() {
  late AppBloc appBloc;

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  group(TrainingPage, () {
    testWidgets('offers the search and the Library', (tester) async {
      when(() => appBloc.state).thenReturn(
        const AppAuthenticated(AuthUser(uid: 'friend', isAnonymous: false)),
      );
      await tester.pumpApp(const TrainingPage(), appBloc: appBloc);
      await tester.pump();

      expect(find.widgetWithText(AppBar, 'Training'), findsOneWidget);
      expect(find.byType(ProfileButton), findsOneWidget);
      expect(find.text('Exercises and workouts'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Workouts'), findsOneWidget);
      expect(find.text('Exercises'), findsOneWidget);
      expect(find.text('Workout History'), findsOneWidget);
    });

    testWidgets('shows nothing when signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(const TrainingPage(), appBloc: appBloc);
      expect(find.text('Library'), findsNothing);
    });

    group('calendar', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      DateTime at(int hour) => DateTime(now.year, now.month, now.day, hour);
      late GoRouter router;

      setUp(() {
        when(() => appBloc.state).thenReturn(
          const AppAuthenticated(AuthUser(uid: programUid, isAnonymous: false)),
        );
        router = _MockGoRouter();
        when(
          () => router.pushNamed<Object?>(
            any(),
            pathParameters: any(named: 'pathParameters'),
          ),
        ).thenAnswer((_) async => null);
      });

      Future<ProgramWorld> pump(
        WidgetTester tester,
        List<WorkoutSessionModel> history,
      ) async {
        final world = ProgramWorld.seeded(
          history: [
            for (final s in history)
              WorkoutSessionModel.fromFirestore({
                ...s.toFirestore(),
                WorkoutSessionModelKeys.authorId: programUid,
              }),
          ],
        );
        await tester.pumpApp(
          InheritedGoRouter(goRouter: router, child: const TrainingPage()),
          appBloc: appBloc,
          workoutSessionRepository: world.sessions,
          userRepository: world.users,
          programRepository: world.programs,
          programsCubit: world.cubit()..userChanged(programUid),
        );
        await tester.pump();
        return world;
      }

      Finder todayCell() =>
          find.bySemanticsLabel(DateFormat.MMMMEEEEd('en').format(today));

      testWidgets('tapping a day with one workout opens it', (tester) async {
        final world = await pump(tester, [trainingSession('s1', on: at(1))]);
        expect(tester.getSemantics(todayCell()).value, 'Today, Logged');
        await tester.tap(todayCell());
        await tester.pump();
        verify(
          () => router.pushNamed<Object?>(
            WorkoutSessionDetailPage.name,
            pathParameters: {WorkoutSessionDetailPage.sessionIdParameter: 's1'},
          ),
        ).called(1);
        expect(
          world.analytics.names,
          containsAllInOrder([
            'TrainingView_OpenCompletedSession_Start',
            'TrainingView_OpenCompletedSession_Success',
          ]),
        );
      });

      testWidgets('tapping an empty day opens nothing', (tester) async {
        final world = await pump(tester, const []);
        await tester.tap(todayCell());
        await tester.pump();
        verifyNever(
          () => router.pushNamed<Object?>(
            any(),
            pathParameters: any(named: 'pathParameters'),
          ),
        );
        expect(
          world.analytics.names.where((n) => n.contains('OpenCompleted')),
          isEmpty,
        );
      });

      testWidgets('a day whose workout is unfinished opens nothing', (
        tester,
      ) async {
        await pump(tester, [trainingSession('s1', on: at(1), finished: false)]);
        await tester.tap(todayCell());
        await tester.pump();
        verifyNever(
          () => router.pushNamed<Object?>(
            any(),
            pathParameters: any(named: 'pathParameters'),
          ),
        );
      });

      testWidgets('a day with two workouts asks which, opening neither', (
        tester,
      ) async {
        final world = await pump(tester, [
          trainingSession('s1', on: at(1)),
          trainingSession('s2', on: at(2)),
        ]);
        await tester.tap(todayCell());
        await tester.pumpAndSettle();
        expect(find.text('Multiple Workouts'), findsOneWidget);
        expect(
          find.text('Which workout would you like to open?'),
          findsOneWidget,
        );
        expect(find.textContaining('Workout s1 · '), findsOneWidget);
        expect(
          world.analytics.names.where((n) => n.contains('OpenCompleted')),
          isEmpty,
        );
        await tester.tap(find.textContaining('Workout s2 · '));
        await tester.pumpAndSettle();
        verify(
          () => router.pushNamed<Object?>(
            WorkoutSessionDetailPage.name,
            pathParameters: {WorkoutSessionDetailPage.sessionIdParameter: 's2'},
          ),
        ).called(1);

        await tester.tap(todayCell());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Multiple Workouts'), findsNothing);
      });

      testWidgets('a workout deleted while choosing is not opened', (
        tester,
      ) async {
        final world = await pump(tester, [
          trainingSession('s1', on: at(1)),
          trainingSession('s2', on: at(2)),
        ]);
        await tester.tap(todayCell());
        await tester.pumpAndSettle();
        await world.sessions.deleteSession(programUid, 's2');
        await tester.pump();
        await tester.tap(find.textContaining('Workout s2 · '));
        await tester.pumpAndSettle();
        verifyNever(
          () => router.pushNamed<Object?>(
            any(),
            pathParameters: any(named: 'pathParameters'),
          ),
        );
        expect(
          world.analytics.names,
          containsAllInOrder([
            'TrainingView_OpenCompletedSession_Start',
            'TrainingView_OpenCompletedSession_Fail',
          ]),
        );
      });

      testWidgets('the calendar button opens the month picker', (tester) async {
        await pump(tester, [trainingSession('s1', on: at(1))]);
        await tester.tap(find.byTooltip('Show calendar'));
        await tester.pumpAndSettle();
        expect(find.text('Calendar'), findsOneWidget);
        await tester.tap(todayCell().last);
        await tester.pumpAndSettle();
        verify(
          () => router.pushNamed<Object?>(
            WorkoutSessionDetailPage.name,
            pathParameters: {WorkoutSessionDetailPage.sessionIdParameter: 's1'},
          ),
        ).called(1);
      });
    });
  });
}
