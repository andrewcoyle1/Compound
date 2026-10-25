import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/notifications/notifications.dart';
import 'package:compound/nutrition/add_meal/view/add_meal_page.dart';
import 'package:compound/nutrition/nutrition.dart';
import 'package:compound/nutrition/recipes/view/recipes_page.dart';
import 'package:compound/onboarding/account_setup/account_setup_cubit.dart';
import 'package:compound/onboarding/onboarding.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/progress/progress.dart';
import 'package:compound/shell/shell.dart';
import 'package:compound/sign_in/sign_in.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:compound/workout_history/workout_history.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPicker;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:social_repository/social_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/app_repositories.dart';
import '../../helpers/display_size.dart';
import '../../helpers/reminder_offers.dart';
import '../../helpers/social_world.dart';

void main() {
  final now = DateTime(2026, 10, 14, 12);
  UserRepository seededUsers() => InMemoryUserRepository(
    users: {sampleUserId: sampleUser(now: now)},
    settings: {sampleUserId: sampleUserSettings(now: now)},
  );

  WorkoutSessionRepository seededSessions() => InMemoryWorkoutSessionRepository(
    sessions: sampleWorkoutSessions(uid: sampleUserId, now: now),
  );

  group(App, () {
    testWidgets('signs in, then out, through the router', (tester) async {
      await tester.pumpWidget(
        App(
          socialRepository: emptySocialRepository(),
          coachRepository: silentCoachRepository(),
          deviceStore: offersShownDevice(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: InMemoryProgramRepository(),
          trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
          authRepository: InMemoryAuthRepository(),
          userRepository: seededUsers(),
          workoutSessionRepository: InMemoryWorkoutSessionRepository(
            sessions: const [],
          ),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SignInPage), findsOneWidget);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Today'), findsOneWidget);

      await tester.tap(find.byType(ProfileButton));
      await tester.pumpAndSettle();
      expect(find.text('Alice Cooper'), findsOneWidget);

      // Signing out is in Settings, as in the Swift app.
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Sign Out'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(find.byType(SignInPage), findsOneWidget);
    });

    testWidgets('a new account is created, onboarded and lands on the tabs', (
      tester,
    ) async {
      final users = InMemoryUserRepository();
      final body = InMemoryBodyRepository();
      final programs = InMemoryProgramRepository();
      final library = InMemoryTrainingLibraryRepository();
      final nutrition = InMemoryNutritionRepository();
      await tester.pumpWidget(
        App(
          socialRepository: emptySocialRepository(),
          coachRepository: silentCoachRepository(),
          deviceStore: offersShownDevice(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: programs,
          trainingLibraryRepository: library,
          authRepository: InMemoryAuthRepository(),
          userRepository: users,
          workoutSessionRepository: InMemoryWorkoutSessionRepository(
            sessions: const [],
          ),
          nutritionRepository: nutrition,
          bodyRepository: body,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue without an account'));
      await tester.pumpAndSettle();
      const uid = 'in-memory-anonymous';
      expect(await users.userExists(uid), isTrue);

      Future<void> next([String label = 'Continue']) async {
        await tester.pump();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      // Account setup.
      expect(find.text("What's Your Name?"), findsWidgets);
      await tester.enterText(find.byType(TextField).first, ' Sam ');
      await tester.pump();
      final cubit = tester
          .element(find.byType(AccountSetupView))
          .read<AccountSetupCubit>();
      expect(cubit.state.firstName, ' Sam ');
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNotNull,
      );
      await next();
      expect(cubit.state.status, AccountSetupStatus.idle);
      expect(cubit.state.question, AccountQuestion.gender);
      expect((await users.watchUser(uid).first)?.submittedFirstName, 'Sam');
      await tester.tap(find.text('Female'));
      await next();
      expect(find.text('When Were You Born?'), findsWidgets);
      await next();
      expect(find.text('How Tall Are You?'), findsWidgets);
      await next();
      expect(find.text("What's Your Weight?"), findsWidgets);
      await next();
      expect(find.text('Do You Work Out?'), findsWidgets);
      await tester.tap(find.text('3-4 times per week'));
      await next();
      await tester.tap(find.text('Moderate Activity'));
      await next();
      expect(find.text('How Much Do You Burn?'), findsWidgets);
      await next();

      // Health disclaimer.
      expect(find.text('Do You Agree?'), findsWidgets);
      for (final toggle in [
        find.byType(Switch).first,
        find.byType(Switch).last,
      ]) {
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
      }
      await tester.pumpAndSettle();
      await next();

      // Goal: maintain skips the target and the rate.
      expect(find.text('What Is Your Goal?'), findsWidgets);
      await tester.tap(find.text('Maintain'));
      await next();
      expect(find.text('Does This Look Right?'), findsWidgets);
      await next();

      // Gym.
      expect(find.text('Create Gym Profile'), findsWidgets);
      await tester.enterText(find.byType(TextField), 'Home');
      await tester.pumpAndSettle();
      await next();
      // Its equipment, then Continue makes it the usual gym.
      expect(find.text('Equipment'), findsOneWidget);
      await next();

      // Program: the recommended one is chosen.
      expect(find.text('Choose a Program'), findsWidgets);
      await next('Start Program');

      // Diet.
      expect(find.text('Ready to Plan Meals?'), findsWidgets);
      await next('Use Recommended Plan');
      expect(find.text('Happy With This?'), findsWidgets);
      await next();

      expect(find.byType(AppShell), findsOneWidget);
      final user = (await users.watchUser(uid).first)!;
      expect(user.submittedFirstName, 'Sam');
      expect(user.submittedGender, Gender.female);
      expect(user.submittedExerciseFrequency, ExerciseFrequency.threeToFour);
      expect(user.submittedDailyActivityLevel, ActivityLevel.moderate);
      expect(user.acceptedHealthDisclaimerVersion, '2025.10.05');
      expect(user.didCompleteOnboarding, isTrue);
      final goal = await body
          .watchCurrentGoal(uid, currentGoalId: user.submittedCurrentGoalId)
          .first;
      expect(goal?.objective, OverarchingObjective.maintain);
      expect(goal?.startingWeightKg, user.submittedWeightKilograms);
      final gyms = await library.watchGymProfiles(uid).first;
      expect(gyms.single.name, 'Home');
      expect(user.submittedFavouriteGymProfileId, gyms.single.id);
      final mesocycles = await programs.watchMesocycles(uid).first;
      expect(mesocycles.single.id, user.submittedActiveMesocycleId);
      expect(mesocycles.single.name, 'Upper/Lower');
      final plan = await nutrition.watchDietPlan(uid).first;
      expect(plan?.planId, uid);
      expect(plan?.preferredDiet, 'balanced');
      expect(plan?.calorieDistribution, 'varied');
      expect(plan?.trainingType, 'Upper/Lower');
    });

    testWidgets('writes the home-screen widgets on leaving the app, answers '
        "the Live Activity's buttons, and clears the widgets on sign-out", (
      tester,
    ) async {
      final auth = InMemoryAuthRepository(
        user: InMemoryAuthRepository.sampleUser,
      );
      final widgets = FakeHomeWidgetRepository();
      final liveActivity = FakeLiveActivityRepository();
      await tester.pumpWidget(
        App(
          socialRepository: emptySocialRepository(),
          coachRepository: silentCoachRepository(),
          deviceStore: offersShownDevice(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: InMemoryProgramRepository(),
          trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
          authRepository: auth,
          userRepository: seededUsers(),
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(),
          homeWidgetRepository: widgets,
          liveActivityRepository: liveActivity,
        ),
      );
      await tester.pumpAndSettle();
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(widgets.snapshot, isNotNull);
      expect(widgets.snapshot!.weeklyGoal, 3);

      // With no workout under way, Finish waits for one, then does nothing
      // but bring the widgets up to date.
      widgets.snapshot = null;
      final tapped = liveActivity.tap(const CompleteWorkoutAction());
      await tester.pump(const Duration(seconds: 9));
      await tapped;
      expect(widgets.snapshot, isNotNull);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(widgets.snapshot, isNull);
    });

    testWidgets('answers Siri: workouts, starting one, weigh-ins, the week, '
        "today's workout and the recipes", (tester) async {
      final intents = FakeAppIntentsRepository();
      final body = InMemoryBodyRepository();
      await tester.pumpWidget(
        App(
          socialRepository: emptySocialRepository(),
          coachRepository: silentCoachRepository(),
          deviceStore: offersShownDevice(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: InMemoryProgramRepository(
            mesocycles: sampleMesocycles(now: now),
          ),
          trainingLibraryRepository: InMemoryTrainingLibraryRepository(
            workoutTemplates: sampleUserWorkoutTemplates,
          ),
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: seededUsers(),
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: body,
          appIntentsRepository: intents,
        ),
      );
      await tester.pumpAndSettle();
      final siri = intents.handler!;

      final workouts = (await tester.runAsync(siri.workouts))!;
      expect(workouts, isNotEmpty);
      expect(workouts.map((w) => w.id).toSet(), hasLength(workouts.length));

      final week = (await tester.runAsync(siri.workoutsThisWeek))!;
      expect(week.sentence, isNotEmpty);
      final today = (await tester.runAsync(siri.todaysWorkout))!;
      expect(today.sentence, isNotEmpty);

      expect(
        await tester.runAsync(() => siri.logWeight(150, pounds: true)),
        'Logged 150.0 lb.',
      );
      expect(
        await tester.runAsync(() => siri.logWeight(70.4, pounds: false)),
        'Logged 70.4 kg.',
      );
      Future<String?> refusal(Future<Object?> Function() ask) =>
          tester.runAsync<String?>(() async {
            try {
              await ask();
              return null;
            } on AppIntentRefusal catch (refusal) {
              return refusal.sentence;
            }
          });
      expect(await refusal(() => siri.logWeight(5)), contains('20 and 400'));
      expect(
        await refusal(() => siri.startWorkout('gone')),
        "That workout isn't in your library any more.",
      );

      await tester.runAsync(siri.browseRecipes);
      await tester.pumpAndSettle();
      expect(find.byType(RecipesPage), findsOneWidget);

      final first = workouts.first;
      expect(
        await tester.runAsync(() => siri.startWorkout(first.id)),
        'Starting ${first.name}.',
      );
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutTrackerPage), findsOneWidget);
      expect(
        await tester.runAsync(() => siri.startWorkout(first.id)),
        contains('already have'),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('offers the quick actions while signed in and routes them', (
      tester,
    ) async {
      final auth = InMemoryAuthRepository(
        user: InMemoryAuthRepository.sampleUser,
      );
      final quick = FakeQuickActionsRepository();
      await tester.pumpWidget(
        App(
          socialRepository: emptySocialRepository(),
          coachRepository: silentCoachRepository(),
          deviceStore: offersShownDevice(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: InMemoryProgramRepository(),
          trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
          authRepository: auth,
          userRepository: seededUsers(),
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(),
          quickActionsRepository: quick,
        ),
      );
      await tester.pumpAndSettle();
      expect(quick.titles, {
        QuickAction.startWorkout: 'Start Workout',
        QuickAction.logWeight: 'Log Weight',
        QuickAction.logMeal: 'Log Meal',
      });

      quick.tap(QuickAction.logWeight);
      await tester.pumpAndSettle();
      expect(find.byType(LogWeightPage), findsOneWidget);

      quick.tap(QuickAction.logMeal);
      await tester.pumpAndSettle();
      expect(find.byType(AddMealPage), findsOneWidget);

      // No programme: Today, where a workout starts.
      quick.tap(QuickAction.startWorkout);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.byType(AddMealPage), findsNothing);
      expect(find.widgetWithText(AppBar, 'Today'), findsOneWidget);

      await auth.signOut();
      await tester.pumpAndSettle();
      expect(quick.titles, isEmpty);
    });

    testWidgets("the Start Workout quick action starts today's workout", (
      tester,
    ) async {
      final quick = FakeQuickActionsRepository();
      await tester.pumpWidget(
        App(
          socialRepository: emptySocialRepository(),
          coachRepository: silentCoachRepository(),
          deviceStore: offersShownDevice(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: InMemoryProgramRepository(
            mesocycles: sampleMesocycles(now: now),
          ),
          trainingLibraryRepository: InMemoryTrainingLibraryRepository(
            workoutTemplates: sampleUserWorkoutTemplates,
          ),
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: seededUsers(),
          workoutSessionRepository: InMemoryWorkoutSessionRepository(
            sessions: const [],
          ),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(),
          quickActionsRepository: quick,
        ),
      );
      await tester.pumpAndSettle();
      quick.tap(QuickAction.startWorkout);
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
      }
      expect(find.byType(WorkoutTrackerPage), findsOneWidget);
    });

    testWidgets('Siri says to sign in first when no one is', (tester) async {
      final intents = FakeAppIntentsRepository();
      await tester.pumpWidget(
        App(
          socialRepository: emptySocialRepository(),
          coachRepository: silentCoachRepository(),
          deviceStore: offersShownDevice(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: InMemoryProgramRepository(),
          trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
          authRepository: InMemoryAuthRepository(),
          userRepository: seededUsers(),
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(),
          appIntentsRepository: intents,
        ),
      );
      await tester.pumpAndSettle();
      Object? refusal;
      unawaited(
        intents.handler!.browseRecipes().catchError((Object e) => refusal = e),
      );
      await tester.pump(const Duration(seconds: 11));
      expect(
        refusal,
        isA<AppIntentRefusal>().having(
          (r) => r.sentence,
          'sentence',
          'Open Compound and sign in first.',
        ),
      );
    });

    testWidgets('starts signed in as the sample user, as staging does, and '
        'shows their profile over the tabs', (tester) async {
      await tester.pumpWidget(
        App(
          socialRepository: emptySocialRepository(),
          coachRepository: silentCoachRepository(),
          deviceStore: offersShownDevice(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: InMemoryProgramRepository(),
          trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: seededUsers(),
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);

      await tester.tap(find.byType(ProfileButton));
      await tester.pumpAndSettle();
      expect(find.text('Alice Cooper'), findsOneWidget);
      expect(find.text('@alice.cooper'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);

      // Closing returns to the tab underneath.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('routes a tapped notification and a compound:// link', (
      tester,
    ) async {
      final notifications = FakeNotificationsRepository();
      final links = FakePlatformLinks();
      await tester.pumpWidget(
        App(
          socialRepository: emptySocialRepository(),
          coachRepository: silentCoachRepository(),
          deviceStore: offersShownDevice(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: InMemoryProgramRepository(),
          trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: seededUsers(),
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(),
          notificationsRepository: notifications,
          platformLinks: links,
        ),
      );
      await tester.pumpAndSettle();
      expect(notifications.tokenUserId, sampleUserId);

      notifications.tap(const {'tab': 'nutrition'});
      await tester.pumpAndSettle();
      expect(find.byType(NutritionView), findsOneWidget);

      links.open(Uri.parse('compound://tab/progress'));
      await tester.pumpAndSettle();
      expect(find.byType(ProgressPage), findsOneWidget);

      // A follow request's push opens the inbox, over Social.
      notifications.tap(const {'type': 'follow_request'});
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);
    });

    testWidgets('shows Page Not Found for an unknown address, with a way '
        'back to Today', (tester) async {
      await tester.pumpWidget(
        App(
          socialRepository: emptySocialRepository(),
          coachRepository: silentCoachRepository(),
          deviceStore: offersShownDevice(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: InMemoryProgramRepository(),
          trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: seededUsers(),
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(
          const MethodCall('pushRouteInformation', {
            'location': '/no-such-screen',
          }),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorState), findsOneWidget);
      expect(find.text('Page Not Found'), findsOneWidget);

      await tester.tap(find.text('Go to Today'));
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorState), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('badges Social with the comments, mentions and requests '
        'waiting', (tester) async {
      final users = seededUsers();
      final social = (await tester.runAsync(
        () => inMemorySocialRepository(
          firestore: FakeFirebaseFirestore(),
          users: users,
          now: DateTime.now(),
        ),
      ))!;
      await tester.pumpWidget(
        App(
          coachRepository: silentCoachRepository(),
          deviceStore: offersShownDevice(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: InMemoryProgramRepository(),
          trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: users,
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(),
          socialRepository: social,
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 400));
      }
      // Maya's comment, Charlie's mention and Bob's request.
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('switches between the five tabs', (tester) async {
      await tester.pumpWidget(
        App(
          socialRepository: emptySocialRepository(),
          coachRepository: silentCoachRepository(),
          deviceStore: offersShownDevice(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: InMemoryProgramRepository(),
          trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: seededUsers(),
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(),
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
        // Nutrition and Progress are ported; the others are still
        // placeholders.
        expect(
          find.byType(NutritionView),
          title == 'Nutrition' ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(ProgressPage),
          title == 'Progress' ? findsOneWidget : findsNothing,
        );
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

    testWidgets('on a wide window, spans the app bar across it, centres '
        "each screen in a readable column, the coach's Today too", (
      tester,
    ) async {
      tester.useSize(const Size(1366, 1024));
      await tester.pumpWidget(
        App(
          socialRepository: emptySocialRepository(),
          coachRepository: silentCoachRepository(),
          deviceStore: offersShownDevice(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: InMemoryProgramRepository(),
          trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: seededUsers(),
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(),
        ),
      );
      await tester.pumpAndSettle();
      double barWidth(String title) =>
          tester.getSize(find.widgetWithText(AppBar, title)).width;
      // The width a screen's content gets: its column.
      double columnWidth(String title) {
        final column = find
            .descendant(
              of: find.ancestor(
                of: find.widgetWithText(AppBar, title),
                matching: find.byType(Scaffold),
              ),
              matching: find.byType(AppReadableWidth),
            )
            .first;
        return tester
            .getSize(
              find
                  .descendant(of: column, matching: find.byType(MediaQuery))
                  .first,
            )
            .width;
      }

      expect(barWidth('Today'), 1366);
      // Today is the coach's day chat: one readable column. With the coach
      // off it is a dashboard (today_page_test).
      expect(columnWidth('Today'), AppContentWidth.readable);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Training'),
        ),
      );
      await tester.pumpAndSettle();
      expect(barWidth('Training'), 1366);
      // Training is a dashboard, in two columns at this width.
      expect(columnWidth('Training'), AppContentWidth.dashboard);
      // The dock spans the window; its tabs keep to the readable column.
      expect(tester.getSize(find.byType(AppTabBar)).width, 1366);
      expect(
        tester.getSize(find.byType(NavigationBar)).width,
        AppContentWidth.readable - 2 * AppSpacing.l,
      );
    });

    testWidgets('opens the workout history and a workout from Training', (
      tester,
    ) async {
      await tester.pumpWidget(
        App(
          socialRepository: emptySocialRepository(),
          coachRepository: silentCoachRepository(),
          deviceStore: offersShownDevice(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: InMemoryProgramRepository(),
          trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: seededUsers(),
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Training'),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Workout History'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workout History'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutHistoryView), findsOneWidget);

      // Newest first: yesterday's Push B.
      await tester.tap(find.text('Push B'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Push B'), findsOneWidget);
      await reveal(tester, find.text('Dumbbell Seated Shoulder Press'));
      expect(find.text('Dumbbell Seated Shoulder Press'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutHistoryView), findsOneWidget);
    });

    testWidgets('opens Weight Trend and its recorded data from Progress', (
      tester,
    ) async {
      await tester.pumpWidget(
        App(
          socialRepository: emptySocialRepository(),
          coachRepository: silentCoachRepository(),
          deviceStore: offersShownDevice(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: InMemoryProgramRepository(),
          trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: seededUsers(),
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(
            measurements: sampleBodyMeasurements(uid: sampleUserId, now: now),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Progress'),
        ),
      );
      await tester.pumpAndSettle();
      // The tab's hero; its title is an overline.
      await tester.tap(find.text('WEIGHT TREND'));
      await tester.pumpAndSettle();
      expect(find.byType(WeightMetricView), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Weight Trend'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Show All Data'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(MetricDetailView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text('Show All Data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show All Data'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'All Recorded Data'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Weight Trend'), findsOneWidget);
    });

    testWidgets('logs a weigh-in from Scale Weight and returns to it', (
      tester,
    ) async {
      final users = seededUsers();
      final body = InMemoryBodyRepository(
        measurements: [
          BodyMeasurementEntry(
            id: 'old',
            authorId: sampleUserId,
            weightKg: 80,
            date: DateTime.now().subtract(const Duration(days: 3)),
            source: WeightSource.manual,
            dateCreated: DateTime.now().subtract(const Duration(days: 3)),
          ),
        ],
      );
      await tester.pumpWidget(
        App(
          socialRepository: emptySocialRepository(),
          coachRepository: silentCoachRepository(),
          deviceStore: offersShownDevice(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: InMemoryProgramRepository(),
          trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: users,
          workoutSessionRepository: seededSessions(),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: body,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Progress'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('SCALE WEIGHT'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ProgressView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('SCALE WEIGHT'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Log Weight'));
      await tester.pumpAndSettle();
      expect(find.byType(LogWeightView), findsOneWidget);
      // It opens on the latest weigh-in, over Scale Weight as a half sheet.
      expect(
        find.descendant(
          of: find.byType(LogWeightView),
          matching: find.text('80 kg'),
        ),
        findsOneWidget,
      );
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      // The test window is short: drag the sheet up to full height.
      await tester.drag(find.text('Date'), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(CupertinoPicker).first,
        const Offset(0, -64),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(LogWeightView), findsNothing);
      expect(find.widgetWithText(AppBar, 'Scale Weight'), findsOneWidget);
      expect(find.text('Latest: Today'), findsOneWidget);
      final saved = await body.watchMeasurements(sampleUserId).first;
      expect(saved, hasLength(2));
      expect(saved.last.weightKg, 82);
      expect(saved.last.source, WeightSource.manual);
      final user = await users.watchUser(sampleUserId).first;
      expect(user?.submittedWeightKilograms, 82);
      expect(
        user?.submittedWeightUnitPreference,
        WeightUnitPreference.kilograms,
      );
    });
  });
}
