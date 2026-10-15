import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/nutrition/nutrition.dart';
import 'package:compound/onboarding/account_setup/account_setup_cubit.dart';
import 'package:compound/onboarding/onboarding.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/progress/progress.dart';
import 'package:compound/shell/shell.dart';
import 'package:compound/sign_in/sign_in.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:compound/workout_history/workout_history.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPicker;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

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

      await tester.ensureVisible(find.text('Sign Out'));
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

    testWidgets('starts signed in as the sample user, as staging does, and '
        'shows their profile over the tabs', (tester) async {
      await tester.pumpWidget(
        App(
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
      expect(find.text('alice@example.com'), findsOneWidget);

      // Closing returns to the tab underneath.
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('routes a tapped notification and a compound:// link', (
      tester,
    ) async {
      final notifications = FakeNotificationsRepository();
      await tester.pumpWidget(
        App(
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
        ),
      );
      await tester.pumpAndSettle();
      expect(notifications.tokenUserId, sampleUserId);

      notifications.tap(const {'tab': 'nutrition'});
      await tester.pumpAndSettle();
      expect(find.byType(NutritionView), findsOneWidget);

      // As the engine sends a URL the app was opened with: whole.
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(
          const MethodCall('pushRouteInformation', {
            'location': 'compound://tab/progress',
          }),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProgressPage), findsOneWidget);
    });

    testWidgets('switches between the five tabs', (tester) async {
      await tester.pumpWidget(
        App(
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

    testWidgets('opens the workout history and a workout from Training', (
      tester,
    ) async {
      await tester.pumpWidget(
        App(
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
      await tester.tap(find.text('Workout History'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutHistoryView), findsOneWidget);

      // Newest first: yesterday's Push B.
      await tester.tap(find.text('Push B'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Push B'), findsOneWidget);
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
      await tester.tap(find.text('Weight Trend'));
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
        find.text('Scale Weight'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ProgressView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scale Weight'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Log Weight'));
      await tester.pumpAndSettle();
      expect(find.byType(LogWeightView), findsOneWidget);
      // It opens on the latest weigh-in.
      expect(find.text('80 kg'), findsOneWidget);
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
