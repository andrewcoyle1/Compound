import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/sharing/share_sheet.dart';
import 'package:compound/sign_in/sign_in.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../helpers/helpers.dart';

// The whole app on in-memory data, as staging runs it: an anonymous account
// saved from Settings, the Rate row, About's version, the method buttons on
// the settings screens and the developer tools.
void main() {
  const anonymous = InMemoryAuthRepository.anonymousUser;
  final today = DateTime.now();
  final created = DateTime(today.year, today.month, today.day - 3, 9);
  // An anonymous account that has finished onboarding.
  final profile = UserModel(
    userId: anonymous.uid,
    isAnonymous: true,
    creationDate: created,
    submittedFirstName: 'Sam',
    submittedGender: Gender.female,
    submittedDateOfBirth: DateTime(1994, 5, 17),
    submittedHeightCentimeters: 168,
    submittedLengthUnitPreference: LengthUnitPreference.centimeters,
    submittedWeightKilograms: 72,
    submittedWeightUnitPreference: WeightUnitPreference.kilograms,
    submittedExerciseFrequency: ExerciseFrequency.threeToFour,
    submittedDailyActivityLevel: ActivityLevel.moderate,
    acceptedHealthDisclaimerVersion: currentHealthDisclaimerVersion,
    submittedCurrentGoalId: 'goal',
    submittedFavouriteGymProfileId: 'gym',
    submittedActiveMesocycleId: 'mesocycle',
    didCompleteOnboarding: true,
  );
  late InMemoryUserRepository users;
  late FakePurchasesRepository purchases;
  late FakeStoreReview store;
  late AnalyticsRecorder analytics;

  setUp(() {
    users = InMemoryUserRepository(users: {anonymous.uid: profile});
    purchases = FakePurchasesRepository();
    store = FakeStoreReview();
    analytics = AnalyticsRecorder();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    ShareSheet shareSheet = const ShareSheet(),
  }) async {
    tester.view
      ..physicalSize = const Size(2400, 9000)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      App(
        socialRepository: emptySocialRepository(),
        coachRepository: silentCoachRepository(),
        appVersion: const AppVersion(version: '1.4.0', build: '27'),
        storeReview: store,
        shareSheet: shareSheet,
        analyticsRepository: analytics,
        purchasesRepository: purchases,
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
        authRepository: InMemoryAuthRepository(user: anonymous),
        userRepository: users,
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: const [],
        ),
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(),
      ),
    );
    await tester.pumpAndSettle();
  }

  GoRouter router(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first));

  Future<void> go(WidgetTester tester, String location) async {
    router(tester).go(location);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('an anonymous account is saved with Google from Settings, '
      'keeping its data, and Settings then offers Sign Out', (tester) async {
    await pumpApp(tester);
    await go(tester, '/profile/settings');
    expect(find.text('Not saved'), findsOneWidget);
    expect(find.text('Sign Out'), findsNothing);

    await tap(tester, find.text('Save Account'));
    expect(
      find.text(
        'Sign in to back up your training and nutrition, and to sync them '
        'across your devices.',
      ),
      findsOneWidget,
    );
    await tap(tester, find.text('Continue with Google'));

    // Back on Settings, as the same account.
    expect(find.text('Save Account'), findsNothing);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text(InMemoryAuthRepository.sampleUser.email!), findsOneWidget);
    final saved = await users.watchUser(anonymous.uid).first;
    expect(saved?.isAnonymous, isFalse);
    expect(saved?.authProviders, ['google']);
    expect(saved?.didCompleteOnboarding, isTrue);
    expect(
      analytics.names,
      containsAllInOrder([
        'Settings_SaveAccount_Press',
        'AuthView_Appear',
        'Auth_GoogleAuth_Start',
        'Auth_GoogleAuth_Success',
        'AuthView_Disappear',
      ]),
    );
  });

  // Flutter tests run as Android, where Apple goes through Firebase's web
  // flow; the staging fake links it the same way.
  testWidgets('an anonymous account is saved with Apple on Android', (
    tester,
  ) async {
    await pumpApp(tester);
    await go(tester, '/profile/settings');
    await tap(tester, find.text('Save Account'));
    await tap(tester, find.text('Continue with Apple'));

    expect(find.text('Save Account'), findsNothing);
    expect(find.text('Apple'), findsOneWidget);
    final saved = await users.watchUser(anonymous.uid).first;
    expect(saved?.isAnonymous, isFalse);
    expect(saved?.authProviders, ['apple']);
    expect(
      analytics.names,
      containsAllInOrder([
        'AuthView_Appear',
        'Auth_AppleAuth_Start',
        'Auth_AppleAuth_Success',
        'AuthView_Disappear',
      ]),
    );
  });

  testWidgets('Rate Compound asks the store, About states the version, and '
      "Methods & Sources lists Swift's 31", (tester) async {
    await pumpApp(tester);
    await go(tester, '/profile/settings');
    await tap(tester, find.text('Rate Compound'));
    expect(store.requests, 1);

    await tap(tester, find.text('About'));
    expect(
      find.textContaining('You are currently on version 1.4.0 (27).'),
      findsOneWidget,
    );

    await go(tester, '/profile/settings/methods');
    expect(find.byType(AppListRowButton), findsNWidgets(31));
  });

  testWidgets('the expenditure, smart progression and timer settings explain '
      'their figures', (tester) async {
    await pumpApp(tester);
    for (final (location, method) in [
      ('/profile/settings/expenditure', 'Resting Calories'),
      ('/profile/settings/expenditure', 'Adaptive Expenditure'),
      ('/profile/settings/workout/smart-progression', 'Smart Progression'),
      ('/profile/settings/workout/rest-timer/durations', 'Rest Timers'),
    ]) {
      await go(tester, location);
      await tap(tester, find.byTooltip('How $method is calculated'));
      final sheet = find.byType(MethodInfoSheet);
      expect(sheet, findsOneWidget);
      Navigator.of(tester.element(sheet)).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the developer tools simulate a lapsed subscription, look a '
      'session up and sign out', (tester) async {
    await pumpApp(tester);
    await go(tester, '/profile/settings');
    await tap(tester, find.text('Developer Settings'));
    expect(find.text('Simulate Premium'), findsOneWidget);
    expect(find.text(anonymous.uid), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('No active workout session'),
      500,
      scrollable: find.byType(Scrollable).last,
    );

    await tap(tester, find.text('Simulate Premium'));
    expect(purchases.premium, isFalse);

    await tester.scrollUntilVisible(
      find.byType(TextField),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    await tap(tester, find.text('Fetch Session'));
    expect(find.text('No session has that ID.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Sign Out'),
      -500,
      scrollable: find.byType(Scrollable).last,
    );
    await tap(tester, find.text('Sign Out'));
    expect(find.byType(SignInPage), findsOneWidget);
    expect(
      analytics.names,
      containsAllInOrder([
        'DevSettingsView_ForceSignOut_Start',
        'DevSettingsView_ForceSignOut_Success',
      ]),
    );
  });

  // DevSettingsPresenter.onSaveShareCardsPressed
  testWidgets('the developer tools export the sample share card in both '
      'formats', (tester) async {
    final shares = ShareRecorder();
    await pumpApp(tester, shareSheet: shares);
    await go(tester, '/profile/settings/developer');
    await tap(tester, find.text('Export Share Cards'));
    for (var i = 0; i < 20 && shares.images.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      // Elapses the capture's zero-length delay.
      await tester.pump(Duration.zero);
    }
    expect(
      [for (final (name, png) in shares.images) (name, png.isNotEmpty)],
      [('compound-story.png', true), ('compound-square.png', true)],
    );
  });
}
