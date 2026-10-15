import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/settings/account/view/delete_account_page.dart';
import 'package:compound/settings/general/view/about_page.dart';
import 'package:compound/settings/general/view/customise_analytics_page.dart';
import 'package:compound/settings/general/view/legal_page.dart';
import 'package:compound/settings/general/view/methods_and_sources_page.dart';
import 'package:compound/settings/general/view/notification_settings_page.dart';
import 'package:compound/settings/general/view/units_page.dart';
import 'package:compound/settings/nutrition/view/expenditure_settings_page.dart';
import 'package:compound/settings/nutrition/view/food_log_settings_page.dart';
import 'package:compound/settings/nutrition/view/strategy_settings_page.dart';
import 'package:compound/settings/settings.dart';
import 'package:compound/settings/training/view/workout_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  const appleUser = AuthUser(
    uid: 'uid',
    isAnonymous: false,
    providers: {SignInProvider.apple},
  );
  late AppBloc appBloc;
  late AuthRepository authRepository;

  setUp(() {
    appBloc = MockAppBloc();
    authRepository = MockAuthRepository();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Future<void> pumpSettings(
    WidgetTester tester, {
    AuthUser user = appleUser,
    UserModel? profile = const UserModel(
      userId: 'uid',
      email: 'ada@example.com',
    ),
  }) async {
    when(() => appBloc.state).thenReturn(
      AppAuthenticated(
        user,
        profile: profile,
        profileStatus: AppProfileStatus.ready,
      ),
    );
    tester.view.physicalSize = const Size(2400, 9000);
    addTearDown(tester.view.reset);
    await tester.pumpApp(
      const SizedBox(),
      appBloc: appBloc,
      authRepository: authRepository,
      // The screens the rows open read these.
      userRepository: InMemoryUserRepository(),
      bodyRepository: InMemoryBodyRepository(),
      router: GoRouter(
        initialLocation: '/profile/settings',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (_, _) => const SizedBox(),
            routes: profileRoutes,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  group(SettingsPage, () {
    testWidgets('says how the person signs in and their email', (tester) async {
      await pumpSettings(tester);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('ada@example.com'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('an anonymous account is not offered Sign Out', (tester) async {
      await pumpSettings(
        tester,
        user: const AuthUser(uid: 'uid', isAnonymous: true),
        profile: const UserModel(userId: 'uid'),
      );
      expect(find.text('Not saved'), findsOneWidget);
      expect(find.text('Not provided'), findsOneWidget);
      expect(find.text('Sign Out'), findsNothing);
    });

    for (final (row, page) in [
      ('Notification Settings', NotificationSettingsPage),
      ('Units', UnitsPage),
      ('Analytics', CustomiseAnalyticsPage),
      ('Food Log', FoodLogSettingsPage),
      ('Expenditure', ExpenditureSettingsPage),
      ('Strategy', StrategySettingsPage),
      ('Workout Settings', WorkoutSettingsPage),
      ('Legal', LegalPage),
      ('Methods & Sources', MethodsAndSourcesPage),
      ('About', AboutPage),
      ('Delete Account', DeleteAccountPage),
    ]) {
      testWidgets('$row opens its screen', (tester) async {
        await pumpSettings(tester);
        await tester.tap(find.text(row));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(page), findsOneWidget);
      });
    }

    testWidgets('Support says where to write', (tester) async {
      await pumpSettings(tester);
      await tester.tap(find.text('Support'));
      await tester.pumpAndSettle();
      expect(
        find.text('Email $supportEmail and we will get back to you.'),
        findsOneWidget,
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('OK'), findsNothing);
    });

    testWidgets('signs out, and says so when that fails', (tester) async {
      when(authRepository.signOut).thenThrow(const AuthFailure('offline'));
      await pumpSettings(tester);
      await tester.tap(find.text('Sign Out'));
      await tester.pump();
      verify(authRepository.signOut).called(1);
      expect(find.text('Unable to Sign Out'), findsOneWidget);
    });

    testWidgets('shows nothing once signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(
        const SettingsPage(),
        appBloc: appBloc,
        authRepository: authRepository,
      );
      expect(find.text('Settings'), findsNothing);
    });
  });
}
