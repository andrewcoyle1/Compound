import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/challenges/challenges.dart';
import 'package:compound/challenges/view/challenge_detail_page.dart';
import 'package:compound/challenges/view/create_challenge_page.dart';
import 'package:compound/social/invite/invite_cubit.dart';
import 'package:compound/social/profile/social_profile_page.dart';
import 'package:compound/social/social.dart';
import 'package:connectivity_repository/connectivity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../helpers/helpers.dart';

void main() {
  late SocialWorld world;
  late ChallengesCubit challenges;
  late InviteCubit invites;
  late AnalyticsRecorder analytics;
  late GoRouter router;

  // The dashboard's list, not the circle strip across it.
  final dashboard = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  /// Social, with [location] pushed over it when given.
  Future<void> pump(WidgetTester tester, [String? location]) async {
    analytics = AnalyticsRecorder();
    world = (await tester.runAsync(
      () => SocialWorld.create(analytics: analytics),
    ))!;
    challenges = ChallengesCubit(social: world.social, analytics: analytics)
      ..viewerChanged(sampleUserId);
    invites = InviteCubit(
      connectivity: FakeConnectivityRepository(),
      social: world.social,
      analytics: analytics,
    );
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
      circleBloc: world.circle,
      challengesCubit: challenges,
      inviteCubit: invites,
      router: router = GoRouter(
        initialLocation: '/social',
        routes: [
          GoRoute(path: '/social', builder: (_, _) => const SocialPage()),
          ...socialRoutes,
          ...challengeRoutes,
        ],
      ),
    );
    await settle(tester);
    if (location != null) {
      unawaited(router.push(location));
      await settle(tester);
    }
  }

  group('Challenges', () {
    testWidgets('Social shows the running challenges and opens one', (
      tester,
    ) async {
      await pump(tester);

      await tester.scrollUntilVisible(
        find.text('October Grind'),
        200,
        scrollable: dashboard.first,
      );
      await tester.ensureVisible(find.text('October Grind'));
      await tester.pump();
      expect(find.text('Challenges'), findsOneWidget);
      expect(find.text('Two-Week Kickstart'), findsOneWidget);
      // October Grind: Maya 7, the viewer 5, Charlie 4, by display name.
      expect(find.text('1. Maya Chen 7'), findsOneWidget);
      expect(find.text('2. You 5'), findsOneWidget);

      await tester.tap(find.text('October Grind'));
      await settle(tester);
      expect(find.byType(ChallengeDetailPage), findsOneWidget);
      expect(find.text('Train 12 times'), findsOneWidget);
      expect(find.text('Standings'), findsOneWidget);
      expect(analytics.names, contains('SocialView_Challenge_Press'));
      expect(analytics.names, contains('ChallengeDetailView_Appear'));

      // ChallengesPresenterTests.testTappingAMemberOpensTheirProfile
      await tester.tap(find.bySemanticsLabel(RegExp('^1. Maya')));
      await settle(tester);
      expect(find.byType(SocialProfilePage), findsOneWidget);
    });

    testWidgets('creates a challenge, which Social then shows', (tester) async {
      await pump(tester);
      await tester.scrollUntilVisible(
        find.text('New'),
        200,
        scrollable: dashboard.first,
      );
      await tester.ensureVisible(find.text('New'));
      await tester.pump();
      await tester.tap(find.text('New'));
      await settle(tester);
      expect(find.byType(CreateChallengePage), findsOneWidget);
      expect(find.text('Give the challenge a name.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Push Week');
      await tester.pump();
      expect(find.text('Invite at least one person.'), findsOneWidget);
      await tester.tap(find.byTooltip('Target: 9 sessions'));
      await tester.tap(find.text('7 days'));
      await tester.tap(find.text('Maya Chen'));
      await tester.pump();
      expect(find.text('Target: 9 sessions'), findsOneWidget);

      await tester.tap(find.byTooltip('Create'));
      await settle(tester);
      expect(find.byType(CreateChallengePage), findsNothing);
      final created = challenges.state.challenges.firstWhere(
        (challenge) => challenge.title == 'Push Week',
      );
      expect(created.targetSessions, 9);
      expect(created.memberIds, [sampleUserId, 'user1']);
      expect(
        (await tester.runAsync(() => world.social.challenge(created.id)))!
            .title,
        'Push Week',
      );
      await tester.scrollUntilVisible(
        find.text('Push Week'),
        200,
        scrollable: dashboard.first,
      );
      await tester.ensureVisible(find.text('Push Week'));
      await tester.pump();
      expect(find.text('Push Week'), findsOneWidget);
    });

    testWidgets('closing with something typed asks first', (tester) async {
      await pump(tester, '/challenges/new');
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      expect(find.byType(CreateChallengePage), findsNothing);

      await pump(tester, '/challenges/new');
      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard Changes?'), findsOneWidget);
      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateChallengePage), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard Changes'));
      await settle(tester);
      expect(find.byType(CreateChallengePage), findsNothing);
    });

    // ChallengesPresenterTests.testLeavingConfirmsFirst
    testWidgets('leaving confirms first, then takes the viewer out', (
      tester,
    ) async {
      await pump(tester);
      unawaited(challenges.refresh());
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text('Two-Week Kickstart'),
        200,
        scrollable: dashboard.first,
      );
      await tester.ensureVisible(find.text('Two-Week Kickstart'));
      await tester.pump();
      await tester.tap(find.text('Two-Week Kickstart'));
      await settle(tester);

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave Challenge'));
      await tester.pumpAndSettle();
      expect(find.text('Leave Two-Week Kickstart?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(ChallengeDetailPage), findsOneWidget);

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave Challenge'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await settle(tester);
      expect(find.byType(ChallengeDetailPage), findsNothing);
      expect(challenges.state.challenge('mock_challenge_2'), isNull);
      expect(find.text('Two-Week Kickstart'), findsNothing);
    });

    testWidgets('a challenge that cannot be read says so', (tester) async {
      await pump(tester, '/challenges/missing');
      expect(find.text('This challenge is no longer available.'), findsOne);
    });
  });

  group('Invites', () {
    testWidgets('search offers the invite link and a code to type', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.pump();

      await tester.tap(find.text('Invite a Friend'));
      await settle(tester);
      expect(invites.state.result, isA<InviteShareReady>());
      expect(analytics.names, contains('SocialView_InviteFriend_Press'));

      await tester.tap(find.text('Enter Invite Code'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Join'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'push-2345');
      await tester.pump();
      await tester.tap(find.byTooltip('Join'));
      await settle(tester);
      expect((invites.state.result! as InviteAccepted).inviter.userId, 'user1');
    });

    testWidgets('the invite card shares and goes away', (tester) async {
      await pump(tester);
      // The sample user has more than five finished workouts.
      expect(find.text('Invite a friend'), findsOneWidget);
      await tester.tap(find.text('Invite a friend'));
      await settle(tester);
      expect(find.text('Invite a friend'), findsNothing);
      expect(invites.state.result, isA<InviteShareReady>());
      expect(analytics.names, contains('SocialView_InviteCard_Press'));
    });

    testWidgets('the invite card can be closed', (tester) async {
      await pump(tester);
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Invite a friend'),
            matching: find.byType(AppCard),
          ),
          matching: find.byTooltip('Dismiss'),
        ),
      );
      await settle(tester);
      expect(find.text('Invite a friend'), findsNothing);
      expect(invites.state.result, isNull);
      expect(analytics.names, contains('SocialView_InviteCard_Dismiss'));
    });
  });
}
