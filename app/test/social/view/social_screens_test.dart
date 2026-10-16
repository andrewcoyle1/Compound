import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/settings/account/username/edit_username_page.dart';
import 'package:compound/social/comments/comments_page.dart';
import 'package:compound/social/followers/people_list_page.dart';
import 'package:compound/social/profile/social_profile_page.dart';
import 'package:compound/social/social.dart';
import 'package:compound/social/weekly_goal/weekly_goal_sheet.dart';
import 'package:compound_models/compound_models.dart' show UserModelKeys;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  late SocialWorld world;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> pump(
    WidgetTester tester,
    String location, {
    UserModel? profile,
  }) async {
    world = (await tester.runAsync(SocialWorld.create))!;
    final appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      AppAuthenticated(
        const AuthUser(uid: sampleUserId, isAnonymous: false),
        profile: profile ?? world.viewer,
        profileStatus: AppProfileStatus.ready,
      ),
    );
    await tester.pumpApp(
      const SizedBox(),
      appBloc: appBloc,
      userRepository: world.users,
      workoutSessionRepository: world.sessions,
      socialRepository: world.social,
      circleBloc: world.circle,
      router: GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(path: '/social', builder: (_, _) => const SocialPage()),
          ...socialRoutes,
        ],
      ),
    );
    await settle(tester);
  }

  group(SocialPage, () {
    testWidgets('shows the circle, the week and the feed', (tester) async {
      await pump(tester, '/social');

      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('Nudge'), findsWidgets);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('Workout Feed'), findsOneWidget);
      expect(find.text('Find People'), findsOneWidget);

      await tester.tap(find.text('This Week'));
      await tester.pumpAndSettle();
      expect(find.text('You'), findsOneWidget);

      await tester.tap(find.text('Nudge').first);
      await settle(tester);
      expect(world.circle.state.nudgedOn(DateTime.now()), hasLength(1));
    });

    testWidgets('searches people and follows from the results', (tester) async {
      await pump(tester, '/social');

      await tester.tap(find.text('Find People'));
      await tester.pump();
      expect(
        find.text(
          'Search by name or @username, or bring a friend in with an invite.',
        ),
        findsOneWidget,
      );
      expect(find.text('Invite a Friend'), findsOneWidget);
      expect(find.text('Enter Invite Code'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'Dav');
      await settle(tester);
      expect(find.text('People'), findsOneWidget);
      expect(find.text('David Kerr'), findsOneWidget);
      await tester.tap(find.text('Follow'));
      await settle(tester);
      expect(
        (await tester.runAsync(
          () => world.users.watchUser(sampleUserId).first,
        ))!.followingIds,
        contains('user6'),
      );

      await tester.enterText(find.byType(EditableText), 'zzz');
      await settle(tester);
      expect(find.text('No Results for “zzz”'), findsOneWidget);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pump();
      expect(find.text('Workout Feed'), findsOneWidget);
    });

    testWidgets('likes a workout and opens its comments', (tester) async {
      await pump(tester, '/social');

      await tester.ensureVisible(find.bySemanticsLabel('Like').first);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Like').first);
      await settle(tester);

      await tester.ensureVisible(find.bySemanticsLabel('Comments').first);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Comments').first);
      await settle(tester);
      expect(find.byType(CommentsPage), findsOneWidget);
    });

    testWidgets('asks for a username and opens the profile from a face', (
      tester,
    ) async {
      world = (await tester.runAsync(SocialWorld.create))!;
      world.circle.add(
        CircleViewerChanged(
          UserModel.fromFirestore(
            {...world.viewer.toFirestore()}..remove(UserModelKeys.username),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      final appBloc = MockAppBloc();
      when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => appBloc.state).thenReturn(
        AppAuthenticated(
          const AuthUser(uid: sampleUserId, isAnonymous: false),
          profile: world.circle.state.viewer,
          profileStatus: AppProfileStatus.ready,
        ),
      );
      await tester.pumpApp(
        const SizedBox(),
        appBloc: appBloc,
        userRepository: world.users,
        workoutSessionRepository: world.sessions,
        socialRepository: world.social,
        circleBloc: world.circle,
        router: GoRouter(
          initialLocation: '/social',
          routes: [
            GoRoute(path: '/social', builder: (_, _) => const SocialPage()),
            ...socialRoutes,
          ],
        ),
      );
      await settle(tester);

      expect(find.text('Pick a username so friends can find you'), findsOne);
      await tester.tap(find.text('Pick a username so friends can find you'));
      await settle(tester);
      expect(find.byType(EditUsernamePage), findsOneWidget);
      await tester.pageBack();
      await settle(tester);

      await tester.tap(find.byTooltip('Dismiss').first);
      await settle(tester);
      expect(
        find.text('Pick a username so friends can find you'),
        findsNothing,
      );

      await tester.tap(find.text('Charlie'));
      await settle(tester);
      expect(find.byType(SocialProfilePage), findsOneWidget);
    });
  });

  group(SocialProfilePage, () {
    testWidgets('shows someone else’s profile, people and workouts', (
      tester,
    ) async {
      await pump(tester, '/people/user1');

      expect(find.text('@maya.chen'), findsOneWidget);
      expect(find.text('Maya Chen'), findsWidgets);
      expect(find.text('Follows you'), findsOneWidget);
      expect(find.text('Following'), findsWidgets);
      expect(find.text('People you both follow'), findsOneWidget);
      expect(find.text('Consistency'), findsOneWidget);

      await tester.tap(find.text('Activities'));
      await tester.pump();
      expect(find.text('Recent Workouts'), findsOneWidget);

      await tester.tap(find.text('See All'));
      await settle(tester);
      expect(find.byType(PeopleListPage), findsOneWidget);
      expect(find.text('People You Both Follow'), findsOneWidget);
      await tester.pageBack();
      await settle(tester);

      await tester.tap(find.text('Followers'));
      await settle(tester);
      expect(find.text('Charlie Nguyen'), findsOneWidget);
    });

    testWidgets('locks a private profile and blocks', (tester) async {
      await pump(tester, '/people/user2');

      expect(
        find.text('This account is private. Follow it to see its workouts.'),
        findsOneWidget,
      );
      expect(find.text('Activities'), findsNothing);

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block Bob Martinez'));
      await tester.pumpAndSettle();
      expect(find.text('Block Bob Martinez?'), findsOneWidget);
      await tester.tap(find.text('Block'));
      await settle(tester);
      expect(
        (await tester.runAsync(
          () => world.users.watchUser(sampleUserId).first,
        ))!.blockedUserIds,
        ['user2'],
      );
    });
  });

  group(CommentsPage, () {
    testWidgets('shows the thread, replies and posts', (tester) async {
      await pump(
        tester,
        '/sessions/user1/user1-sample-session-push-b/comments',
      );

      expect(find.text('Great session! 💪'), findsOneWidget);
      expect(find.text('Same time next week?'), findsOneWidget);

      await tester.tap(find.text('Reply').first);
      await tester.pump();
      expect(find.text('Replying to Charlie Nguyen'), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel reply'));
      await tester.pump();

      await tester.enterText(find.byType(EditableText), 'Hi @ma');
      await settle(tester);
      await tester.tap(find.text('@maya.chen'));
      await tester.pump();
      await tester.tap(find.byTooltip('Send comment'));
      await settle(tester);
      expect(find.text('Hi @maya.chen'), findsOneWidget);

      await tester.tap(find.byIcon(AppSymbols.heart).first);
      await settle(tester);

      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await settle(tester);
      expect(find.text('Hi @maya.chen'), findsNothing);
    });

    testWidgets('starts an empty thread', (tester) async {
      await pump(tester, '/sessions/user4/nothing/comments');
      expect(find.text('No Comments Yet'), findsOneWidget);
    });
  });

  group(EditUsernamePage, () {
    testWidgets('checks and saves a handle', (tester) async {
      await pump(tester, '/username');
      expect(find.text('This is your username.'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'ab');
      await tester.pump();
      expect(find.text('At least 3 characters'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'charlie.c');
      await settle(tester);
      expect(find.text('Taken'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'alice_two');
      await settle(tester);
      expect(find.text('Available'), findsOneWidget);
      await tester.tap(find.byTooltip('Save'));
      await settle(tester);
      expect(
        (await tester.runAsync(
          () => world.users.watchUser(sampleUserId).first,
        ))!.username,
        'alice_two',
      );
    });
  });

  testWidgets('the weekly goal sheet saves a goal', (tester) async {
    await pump(tester, '/social');
    final context = tester.element(find.byType(SocialPage));
    unawaited(showWeeklyGoalSheet(context, world.viewer));
    await tester.pumpAndSettle();
    expect(find.text('3 sessions a week'), findsOneWidget);
    await tester.tap(find.text('5'));
    await settle(tester);
    expect(
      (await tester.runAsync(() => world.users.watchUser(sampleUserId).first))!
          .weeklySessionGoal,
      5,
    );
  });
}
