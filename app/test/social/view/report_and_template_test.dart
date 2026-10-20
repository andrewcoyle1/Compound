import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/programs/cubit/programs_cubit.dart';
import 'package:compound/social/feed/feed_session_card.dart';
import 'package:compound/social/report/report_sheet.dart';
import 'package:compound/social/social.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

// The flows on the staging world, in place of tapping them through on a
// simulator: reporting a comment, a workout and a profile, Save as
// Template from a feed card, and the own profile's mesocycle line.
void main() {
  late SocialWorld world;
  late AnalyticsRecorder analytics;
  late InMemoryTrainingLibraryRepository library;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> pump(
    WidgetTester tester,
    String location, {
    ProgramsCubit? programsCubit,
    bool withViewer = false,
  }) async {
    world = (await tester.runAsync(SocialWorld.create))!;
    analytics = AnalyticsRecorder();
    library = InMemoryTrainingLibraryRepository();
    final appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      AppAuthenticated(
        const AuthUser(uid: sampleUserId, isAnonymous: false),
        profile: world.viewer,
        profileStatus: AppProfileStatus.ready,
      ),
    );
    await tester.pumpApp(
      const SizedBox(),
      appBloc: appBloc,
      analyticsRepository: analytics,
      userRepository: world.users,
      workoutSessionRepository: world.sessions,
      socialRepository: world.social,
      trainingLibraryRepository: library,
      circleBloc: world.circle,
      programsCubit: programsCubit,
      router: GoRouter(
        initialLocation: location,
        // The profile button hands over the reader's own profile.
        initialExtra: withViewer ? world.viewer : null,
        routes: [
          GoRoute(path: '/social', builder: (_, _) => const SocialPage()),
          ...socialRoutes,
        ],
      ),
    );
    await settle(tester);
  }

  Future<void> send(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Send'));
    await settle(tester);
  }

  testWidgets('reports someone else’s comment, asking for a reason first', (
    tester,
  ) async {
    await pump(tester, '/sessions/user1/user1-sample-session-push-b/comments');

    // Charlie's comment can be reported; the reader's own reply cannot.
    expect(find.text('Report'), findsOneWidget);
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(find.text('Report Comment'), findsOneWidget);
    expect(find.text('Why are you reporting this comment?'), findsOneWidget);

    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(find.text('Choose a reason for the report.'), findsOneWidget);

    await tester.tap(find.text('Other'));
    await tester.pump();
    expect(find.text('Tell us what is wrong.'), findsOneWidget);
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(find.text('Add a note saying what is wrong.'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(ReportView),
        matching: find.byType(EditableText),
      ),
      'Not about the workout',
    );
    await send(tester);
    expect(find.byType(ReportView), findsNothing);
    expect(
      find.text('Report sent. Thanks — we will take a look at this comment.'),
      findsOneWidget,
    );
    expect(analytics.parameters('Report_Submit_Start'), {
      'content_type': 'comment',
      'content_id': 'sample-comment-1',
      'reason': 'other',
    });
  });

  testWidgets('closing the sheet sends nothing', (tester) async {
    await pump(tester, '/sessions/user1/user1-sample-session-push-b/comments');

    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spam'));
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);

    expect(find.byType(ReportView), findsNothing);
    expect(analytics.names, isNot(contains('ReportFlow_Report_Start')));
  });

  testWidgets('reports a profile from its menu', (tester) async {
    await pump(tester, '/people/user1');

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report…'));
    await tester.pumpAndSettle();
    expect(find.text('Report Profile'), findsOneWidget);
    await tester.tap(find.text('Harassment'));
    await tester.pump();
    await send(tester);

    expect(
      find.text('Report sent. Thanks — we will take a look at this profile.'),
      findsOneWidget,
    );
    expect(analytics.parameters('Report_Submit_Start'), {
      'content_type': 'user',
      'content_id': 'user1',
      'reason': 'harassment',
    });
  });

  testWidgets('a feed card saves its workout as a template, and reports it', (
    tester,
  ) async {
    await pump(tester, '/people/user1');
    await tester.tap(find.text('Activities'));
    await tester.pump();
    final card = find.byType(FeedSessionCard).first;
    await tester.scrollUntilVisible(
      card,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final session = tester.widget<FeedSessionCard>(card).entry.session;

    Future<void> openMenu() async {
      final more = find.descendant(
        of: card,
        matching: find.bySemanticsLabel('More actions'),
      );
      await tester.ensureVisible(more);
      await tester.pump();
      await tester.tap(more);
      await settle(tester);
    }

    await openMenu();
    expect(find.text('Report Workout…'), findsOneWidget);
    await tester.tap(find.text('Save as Template'));
    await settle(tester);
    final saved = (await tester.runAsync(
      () => library.watchUserWorkoutTemplates(sampleUserId).first,
    ))!;
    expect(saved.single.name, session.name);
    expect(find.text('Saved ${session.name} to your workouts'), findsOneWidget);

    await openMenu();
    await tester.tap(find.text('Report Workout…'));
    await tester.pumpAndSettle();
    expect(find.text('Report Workout'), findsOneWidget);
    await tester.tap(find.text('Inappropriate'));
    await tester.pump();
    await send(tester);
    expect(analytics.parameters('ReportFlow_Report_Success'), {
      'content_type': 'session',
      'reason': 'inappropriate',
    });
  });

  testWidgets('the own profile names the mesocycle being followed', (
    tester,
  ) async {
    final now = DateTime.now();
    final mesocycles = sampleMesocycles(now: now);
    final users = InMemoryUserRepository(
      users: {sampleUserId: sampleUser(now: now)},
    );
    final sessions = InMemoryWorkoutSessionRepository(sessions: const []);
    final programs = ProgramsCubit(
      programs: InMemoryProgramRepository(mesocycles: mesocycles),
      users: users,
      sessions: sessions,
      service: ProgramService(
        programs: InMemoryProgramRepository(),
        users: users,
        sessions: sessions,
      ),
      setup: TrainingSetupService(
        programs: InMemoryProgramRepository(),
        library: InMemoryTrainingLibraryRepository(),
        users: users,
      ),
      analytics: AnalyticsRecorder(),
    );
    await tester.runAsync(() async {
      programs.userChanged(sampleUserId);
      await programs.stream.firstWhere((s) => s.activeMesocycle != null);
    });
    await pump(
      tester,
      '/people/$sampleUserId',
      programsCubit: programs,
      withViewer: true,
    );

    expect(find.text('Following ${mesocycles.first.name}'), findsOneWidget);
  });
}
