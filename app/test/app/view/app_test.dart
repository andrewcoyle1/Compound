import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/shell/shell.dart';
import 'package:compound/sign_in/sign_in.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_repository/user_repository.dart';

void main() {
  final now = DateTime(2026, 10, 14, 12);
  UserRepository seededUsers() => InMemoryUserRepository(
    users: {sampleUserId: sampleUser(now: now)},
    settings: {sampleUserId: sampleUserSettings(now: now)},
  );

  group(App, () {
    testWidgets('signs in, then out, through the router', (tester) async {
      await tester.pumpWidget(
        App(
          authRepository: InMemoryAuthRepository(),
          userRepository: InMemoryUserRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SignInPage), findsOneWidget);

      await tester.tap(find.text('Continue without an account'));
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Today'), findsOneWidget);

      await tester.tap(find.byType(ProfileButton));
      await tester.pumpAndSettle();
      expect(find.text("Your profile couldn't be loaded."), findsOneWidget);

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(find.byType(SignInPage), findsOneWidget);
    });

    testWidgets('starts signed in as the sample user, as staging does, and '
        'shows their profile over the tabs', (tester) async {
      await tester.pumpWidget(
        App(
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: seededUsers(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);

      await tester.tap(find.byType(ProfileButton));
      await tester.pumpAndSettle();
      expect(find.text('Alice Cooper'), findsOneWidget);
      expect(find.text('@alice.cooper'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);

      // Closing returns to the tab underneath.
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('switches between the five tabs', (tester) async {
      await tester.pumpWidget(
        App(
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: seededUsers(),
        ),
      );
      await tester.pumpAndSettle();

      for (final title in ['Training', 'Nutrition', 'Progress', 'Social']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(title),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, title), findsOneWidget);
      }

      // Tapping the current tab again stays on it.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Social'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Social'), findsOneWidget);
    });
  });
}
