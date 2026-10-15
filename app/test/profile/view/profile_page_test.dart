import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/settings/account/view/edit_profile_page.dart';
import 'package:compound/settings/settings.dart';
import 'package:compound/social/social_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  group(ProfilePage, () {
    late SocialWorld world;

    Future<void> pump(WidgetTester tester, {GoRouter? router}) async {
      world = (await tester.runAsync(SocialWorld.create))!;
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
        appBloc: appBloc,
        const ProfilePage(),
        userRepository: world.users,
        workoutSessionRepository: world.sessions,
        socialRepository: world.social,
        circleBloc: world.circle,
        router: router,
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }

    testWidgets('is the reader’s own social profile', (tester) async {
      await pump(tester);

      expect(find.text('@alice.cooper'), findsOneWidget);
      expect(find.text('Alice Cooper'), findsOneWidget);
      expect(find.text('Goal: 3 sessions a week'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      // No follow button on one's own profile.
      expect(find.text('Follow'), findsNothing);
    });

    testWidgets('shows nothing while nobody is signed in', (tester) async {
      await tester.pumpApp(const ProfilePage());
      expect(find.text('Edit Profile'), findsNothing);
    });

    for (final (control, page) in [
      (find.byTooltip('Settings'), SettingsPage),
      (find.text('Edit Profile'), EditProfilePage),
    ]) {
      testWidgets('opens $page', (tester) async {
        await pump(
          tester,
          router: GoRouter(
            initialLocation: ProfilePage.path,
            routes: [
              GoRoute(
                path: ProfilePage.path,
                name: ProfilePage.name,
                builder: (_, _) => const ProfilePage(),
                routes: profileRoutes,
              ),
              ...socialRoutes,
            ],
          ),
        );

        await tester.tap(control);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(page), findsOneWidget);
      });
    }
  });
}
