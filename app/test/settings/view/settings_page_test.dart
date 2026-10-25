import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:body_repository/body_repository.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/coach/coach.dart';
import 'package:compound/goal_editing/goal_editing_routes.dart';
import 'package:compound/gym_profiles/view/gym_profiles_page.dart';
import 'package:compound/paywall/paywall.dart';
import 'package:compound/review/review_moment.dart';
import 'package:compound/settings/account/view/delete_account_page.dart';
import 'package:compound/settings/account/view/edit_profile_page.dart';
import 'package:compound/settings/account/view/save_account_page.dart';
import 'package:compound/settings/general/view/about_page.dart';
import 'package:compound/settings/general/view/customise_analytics_page.dart';
import 'package:compound/settings/general/view/legal_page.dart';
import 'package:compound/settings/general/view/methods_and_sources_page.dart';
import 'package:compound/settings/general/view/notification_settings_page.dart';
import 'package:compound/settings/general/view/siri_page.dart';
import 'package:compound/settings/general/view/units_page.dart';
import 'package:compound/settings/nutrition/view/expenditure_settings_page.dart';
import 'package:compound/settings/nutrition/view/food_log_settings_page.dart';
import 'package:compound/settings/nutrition/view/strategy_settings_page.dart';
import 'package:compound/settings/settings.dart';
import 'package:compound/settings/training/view/workout_settings_page.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockCoachAccessCubit extends MockCubit<CoachAccess>
    implements CoachAccessCubit;

void main() {
  const appleUser = AuthUser(
    uid: 'uid',
    isAnonymous: false,
    providers: {SignInProvider.apple},
  );
  late AppBloc appBloc;
  late AuthRepository authRepository;
  late AnalyticsRecorder analytics;
  late FakeStoreReview store;

  setUp(() {
    analytics = AnalyticsRecorder();
    store = FakeStoreReview();
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
    BodyRepository? body,
    UserRepository? users,
    CoachAccessCubit? coach,
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
      analyticsRepository: analytics,
      reviews: ReviewPrompter(review: store),
      // The screens the rows open read these.
      userRepository: users ?? InMemoryUserRepository(),
      coachAccessCubit: coach,
      bodyRepository: body ?? InMemoryBodyRepository(),
      nutritionRepository: InMemoryNutritionRepository(),
      router: GoRouter(
        initialLocation: '/profile/settings',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (_, _) => const SizedBox(),
            routes: profileRoutes,
          ),
          for (final (path, name) in [
            (WeightGoalRoute.path, WeightGoalRoute.name),
            (DietPlanRoute.path, DietPlanRoute.name),
            (PaywallPage.path, PaywallPage.name),
            (CoachChatsPage.path, CoachChatsPage.name),
          ])
            GoRoute(
              path: path,
              name: name,
              builder: (_, state) =>
                  Text('$name screen ${state.uri.query}'.trim()),
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

    testWidgets('the account card says the plan and opens Edit Profile', (
      tester,
    ) async {
      await pumpSettings(tester);
      expect(find.text('PROFILE'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppSummaryCard),
          matching: find.text('Premium'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('PROFILE'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfilePage), findsOneWidget);
    });

    // SettingsPresenterTests: "an anonymous account is offered the upgrade
    // instead of log out" and "saving an anonymous account opens sign in".
    testWidgets('an anonymous account is offered Save Account instead of '
        'Sign Out', (tester) async {
      await pumpSettings(
        tester,
        user: const AuthUser(uid: 'uid', isAnonymous: true),
        profile: const UserModel(userId: 'uid'),
      );
      expect(find.text('Not saved'), findsOneWidget);
      expect(find.text('Not provided'), findsOneWidget);
      expect(find.text('Sign Out'), findsNothing);
      await tester.tap(find.text('Save Account'));
      await tester.pumpAndSettle();
      expect(find.byType(SaveAccountPage), findsOneWidget);
      expect(analytics.names, contains('Settings_SaveAccount_Press'));
    });

    // "The ratings row opens no modal of its own": straight to the store.
    testWidgets('Rate Compound asks the store for a rating', (tester) async {
      await pumpSettings(tester);
      await tester.tap(find.text('Rate Compound'));
      await tester.pumpAndSettle();
      expect(store.requests, 1);
      expect(find.byType(Dialog), findsNothing);
      expect(analytics.names, contains('ProfileView_Ratings_Pressed'));
    });

    testWidgets('offers the developer tools outside production', (
      tester,
    ) async {
      await pumpSettings(tester);
      expect(find.text('Developer Settings'), findsOneWidget);
    });

    for (final (row, page) in [
      ('Notification Settings', NotificationSettingsPage),
      ('Units', UnitsPage),
      ('Analytics', CustomiseAnalyticsPage),
      ('Food Log', FoodLogSettingsPage),
      ('Expenditure', ExpenditureSettingsPage),
      ('Strategy', StrategySettingsPage),
      ('Gym Profiles', GymProfilesPage),
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

    testWidgets('Siri is offered on iOS only, and opens its screen', (
      tester,
    ) async {
      await pumpSettings(tester);
      expect(find.text('Siri'), findsNothing);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await pumpSettings(tester);
      await tester.tap(find.text('Siri'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SiriPage), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    // SettingsPresenterTests' weight goal and nutrition plan rows.
    testWidgets('Weight Goal says Not Set, and sets one straight away', (
      tester,
    ) async {
      await pumpSettings(tester);
      expect(find.text('Weight Goal'), findsOneWidget);
      expect(find.text('Not Set'), findsOneWidget);
      await tester.tap(find.text('Weight Goal'));
      await tester.pumpAndSettle();
      expect(find.text('weightGoal screen'), findsOneWidget);
    });

    testWidgets("Weight Goal shows the running goal's objective and offers "
        'to edit it or start a new one', (tester) async {
      final now = DateTime.now();
      await pumpSettings(
        tester,
        body: InMemoryBodyRepository(
          goals: [sampleWeightGoal(uid: 'uid', now: now)],
        ),
      );
      expect(find.text('Lose weight'), findsOneWidget);
      await tester.tap(find.text('Weight Goal'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Goal'), findsOneWidget);
      await tester.tap(find.text('Start a New Goal'));
      await tester.pumpAndSettle();
      expect(find.text('weightGoal screen'), findsOneWidget);
    });

    testWidgets('Nutrition Plan opens the diet questions', (tester) async {
      await pumpSettings(tester);
      await tester.tap(find.text('Nutrition Plan'));
      await tester.pumpAndSettle();
      expect(find.text('dietPlan screen'), findsOneWidget);
    });

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

    group('Coach', () {
      testWidgets('AI Coach turns the coach off and on; its chats show '
          'while it is on', (tester) async {
        final users = InMemoryUserRepository();
        final coach = CoachAccessCubit(
          coach: CoachRepository(
            firestore: FakeFirebaseFirestore(),
            users: users,
            coachChat: (_, {chatId, context, regenerate = false}) =>
                const Stream.empty(),
          ),
          purchases: FakePurchasesRepository(),
          analytics: analytics,
        )..userChanged('uid');
        await pumpSettings(tester, users: users, coach: coach);

        final toggle = find.widgetWithText(AppListRowToggle, 'AI Coach');
        expect(tester.widget<AppListRowToggle>(toggle).value, isTrue);
        expect(find.text('Chats'), findsOneWidget);

        await tester.tap(toggle);
        await tester.pumpAndSettle();

        expect(tester.widget<AppListRowToggle>(toggle).value, isFalse);
        expect(find.text('Chats'), findsNothing);
        expect(analytics.parameters('SettingsView_Coach_Toggle'), {
          'enabled': false,
        });
        final settings = await users.watchPrivateSettings('uid').first;
        expect(settings?.coachEnabled, isFalse);

        await tester.tap(toggle);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chats'));
        await tester.pumpAndSettle();
        expect(find.text('coachChats screen'), findsOneWidget);
      });

      testWidgets('without premium, AI Coach says Premium and opens the '
          'plans', (tester) async {
        final coach = _MockCoachAccessCubit();
        when(() => coach.state).thenReturn(const CoachAccess(premium: false));
        await pumpSettings(tester, coach: coach);

        expect(find.byType(AppListRowToggle), findsNothing);
        expect(
          find.widgetWithText(AppListRowButton, 'Premium'),
          findsOneWidget,
        );
        expect(find.text('Chats'), findsNothing);

        await tester.tap(find.text('AI Coach'));
        await tester.pumpAndSettle();
        expect(find.text('paywall screen'), findsOneWidget);
      });
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
