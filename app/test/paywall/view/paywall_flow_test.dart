import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/integrations/link_opener.dart';
import 'package:compound/onboarding/logic/staging_onboarding.dart';
import 'package:compound/onboarding/onboarding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

// The whole app on the staging flavor's in-memory data with a fake store
// that is not premium: Swift's subscription gate after signing in, the
// onboarding paywall and every outcome of buying, the resume into
// onboarding after a purchase, the launch into the tabs, and Settings'
// Subscription row.
void main() {
  final now = DateTime.now();
  const anonymous = InMemoryAuthRepository.anonymousUser;

  Future<void> pumpApp(
    WidgetTester tester, {
    required FakePurchasesRepository purchases,
    AuthUser? signedIn,
    UserModel? anonymousProfile,
    LinkOpener linkOpener = const LinkOpener(),
  }) async {
    tester.view
      ..physicalSize = const Size(1290, 2796)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      App(
        socialRepository: emptySocialRepository(),
        coachRepository: silentCoachRepository(),
        purchasesRepository: purchases,
        linkOpener: linkOpener,
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
        authRepository: InMemoryAuthRepository(user: signedIn),
        userRepository: InMemoryUserRepository(
          users: {
            sampleUserId: sampleUser(now: now),
            anonymous.uid: ?anonymousProfile,
          },
        ),
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: const [],
        ),
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(),
      ),
    );
    await tester.pumpAndSettle();
  }

  String location(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri.path;

  Future<void> back(WidgetTester tester) async {
    GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> dismissAlert(WidgetTester tester, String title) async {
    expect(find.text(title), findsOneWidget);
    await tap(tester, find.text('OK'));
    expect(find.text(title), findsNothing);
  }

  testWidgets('signing in without a subscription holds the user at Why '
      'Subscribe; a cancel, a pending purchase, a failure and an empty '
      'restore, then buying, reach Today', (tester) async {
    final purchases = FakePurchasesRepository(
      premium: false,
      failures: const [
        PurchaseCancelled(),
        PurchasePending(),
        PurchasesFailure('declined'),
      ],
    );
    await pumpApp(tester, purchases: purchases);

    await tap(tester, find.text('Continue with Google'));
    expect(location(tester), '/subscribe');
    expect(find.text('Why Subscribe?'), findsWidgets);
    expect(find.text('Personalized plans'), findsOneWidget);

    await tap(tester, find.text('Continue'));
    expect(location(tester), '/subscribe/plans');
    expect(find.text('Pro Annual'), findsOneWidget);
    expect(
      find.text('Plan auto-renews for £29.99 / 1 year until canceled.'),
      findsOneWidget,
    );
    await tap(tester, find.text('Pro Monthly'));
    expect(
      find.text('Plan auto-renews for £4.99 / 1 month until canceled.'),
      findsOneWidget,
    );

    // Cancelled: nothing at all.
    await tap(tester, find.text('Subscribe'));
    expect(find.byType(AlertDialog), findsNothing);
    // Pending: said inline.
    await tap(tester, find.text('Subscribe'));
    expect(find.textContaining('Waiting for approval.'), findsOneWidget);
    // Failed: an alert.
    await tap(tester, find.text('Subscribe'));
    await dismissAlert(tester, 'Unable to Complete Purchase');
    // Restoring an account with nothing on it.
    await tap(tester, find.text('Restore Subscription'));
    await dismissAlert(tester, 'Nothing to Restore');
    // The legal documents.
    await tap(tester, find.text('Terms of Service'));
    expect(location(tester), '/subscribe/plans/legal');
    await back(tester);

    await tap(tester, find.text('Subscribe'));
    expect(location(tester), '/today');
    expect(purchases.state.entitlements.single.productId, contains('monthly'));
  });

  testWidgets('an account still in onboarding resumes its step after '
      'buying, once the plans load', (tester) async {
    final purchases = FakePurchasesRepository(premium: false, failedLoads: 1);
    await pumpApp(
      tester,
      purchases: purchases,
      signedIn: anonymous,
      anonymousProfile: stagingOnboardingProfile(
        OnboardingStep.goalSetting,
        uid: anonymous.uid,
        now: now,
      ),
    );
    expect(location(tester), '/subscribe');

    await tap(tester, find.text('Continue'));
    expect(find.text('Unable to load subscription options'), findsOneWidget);
    await tap(tester, find.text('Try Again'));
    expect(find.text('Pro Annual'), findsOneWidget);

    await tap(tester, find.text('Subscribe'));
    expect(location(tester), OnboardingRoute.goal.path);
  });

  testWidgets('Why Subscribe offers the account and signing out', (
    tester,
  ) async {
    await pumpApp(
      tester,
      purchases: FakePurchasesRepository(premium: false),
      signedIn: anonymous,
      anonymousProfile: stagingOnboardingProfile(
        OnboardingStep.goalSetting,
        uid: anonymous.uid,
        now: now,
      ),
    );

    await tap(tester, find.text('Account'));
    expect(location(tester), '/subscribe/account');
    await back(tester);
    await tap(tester, find.text('Delete Account'));
    expect(location(tester), '/subscribe/delete-account');
    await back(tester);

    // From the plans' account menu too.
    await tap(tester, find.text('Continue'));
    await tap(tester, find.byTooltip('Account'));
    await tap(tester, find.text('Sign Out').last);
    expect(location(tester), '/sign-in');
  });

  testWidgets('a finished user signed in at launch reaches the tabs, and '
      "Settings' Subscription row opens the paywall, then the store's "
      'page once subscribed', (tester) async {
    final links = LinkRecorder();
    final purchases = FakePurchasesRepository(premium: false);
    await pumpApp(
      tester,
      purchases: purchases,
      signedIn: InMemoryAuthRepository.sampleUser,
      linkOpener: links,
    );
    expect(location(tester), '/today');

    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/profile/settings');
    await tester.pumpAndSettle();
    expect(find.text('Inactive'), findsOneWidget);
    await tap(tester, find.text('Subscription'));
    expect(location(tester), '/paywall');

    // Closing it buys nothing.
    await tap(tester, find.byIcon(AppSymbols.close));
    expect(location(tester), '/profile/settings');

    await tap(tester, find.text('Subscription'));
    await tap(tester, find.text('Subscribe'));
    expect(location(tester), '/profile/settings');
    expect(find.text('Active'), findsOneWidget);

    await tap(tester, find.text('Subscription'));
    expect(location(tester), '/profile/settings');
    expect(links.opened, [
      Uri.parse('https://play.google.com/store/account/subscriptions'),
    ]);
  });
}
