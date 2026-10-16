import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/gym_profiles/view/gym_profile_page.dart';
import 'package:compound/onboarding/goal/goal_setup_cubit.dart';
import 'package:compound/onboarding/logic/staging_onboarding.dart';
import 'package:compound/onboarding/onboarding.dart';
import 'package:compound/shell/shell.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// Each step's screen, reached through the router from a profile that
/// resumes there, in memory as the staging flavor runs.
void main() {
  const uid = 'in-memory-anonymous';
  final now = DateTime.now();

  late InMemoryUserRepository users;
  late InMemoryBodyRepository body;
  late InMemoryNutritionRepository nutrition;

  Future<void> pumpAt(
    WidgetTester tester,
    OnboardingStep step, {
    UserRepository? userRepository,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final profile = stagingOnboardingProfile(step, uid: uid, now: now);
    users = InMemoryUserRepository(users: {uid: ?profile});
    body = InMemoryBodyRepository();
    nutrition = InMemoryNutritionRepository();
    await tester.pumpWidget(
      App(
        authRepository: InMemoryAuthRepository(
          user: InMemoryAuthRepository.anonymousUser,
        ),
        userRepository: userRepository ?? users,
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: const [],
        ),
        nutritionRepository: nutrition,
        bodyRepository: body,
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.pump();
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('losing weight at text scale $scale: target, rate and summary, '
        'saved as the goal', (tester) async {
      await pumpAt(tester, OnboardingStep.goalSetting, textScale: scale);
      expect(find.text('What Is Your Goal?'), findsWidgets);
      await tapText(tester, 'Lose weight');
      await tapText(tester, 'Continue');
      expect(find.text("What's Your Target?"), findsWidgets);
      // 72 kg at 168 cm: the wheel stops at 53 kg, a BMI of 18.5.
      expect(
        find.textContaining('The lowest target offered is 53 kg'),
        findsOneWidget,
      );
      // The wheel scrolls itself; pick through the cubit, as it does.
      tester
          .element(find.byType(GoalSetupView))
          .read<GoalSetupCubit>()
          .targetWheelChanged(65);
      await tester.pumpAndSettle();
      await tapText(tester, 'Continue');
      expect(find.text('At What Rate?'), findsWidgets);
      expect(find.text('Standard (Recommended)'), findsOneWidget);
      expect(find.textContaining('-0.55 kg'), findsOneWidget);
      expect(
        find.textContaining('kcal estimated daily calorie target'),
        findsOneWidget,
      );
      expect(find.textContaining('Your target will step down'), findsOneWidget);

      // Back to the target, then on again.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text("What's Your Target?"), findsWidgets);
      await tapText(tester, 'Continue');
      await tapText(tester, 'Continue');
      expect(find.text('Does This Look Right?'), findsWidgets);
      expect(find.text('Estimated Timeline'), findsOneWidget);
      await tapText(tester, 'Continue');

      final user = (await users.watchUser(uid).first)!;
      final goal = await body
          .watchCurrentGoal(uid, currentGoalId: user.submittedCurrentGoalId)
          .first;
      expect(goal?.objective, OverarchingObjective.loseWeight);
      expect(goal?.startingWeightKg, 72);
      expect(goal?.targetWeightKg, 65);
      expect(goal?.weeklyChangeKg, closeTo(0.55, 1e-9));
      expect(find.text('Create Gym Profile'), findsWidgets);
    });

    testWidgets('customising the diet at text scale $scale answers each '
        'question, then finishes', (tester) async {
      await pumpAt(tester, OnboardingStep.customiseProgram, textScale: scale);
      await tapText(tester, 'Customize');
      expect(find.text("What's Your Diet?"), findsWidgets);
      await tapText(tester, 'Keto');
      await tapText(tester, 'Continue');
      expect(find.text('Even or Varied?'), findsWidgets);
      await tapText(tester, 'Vary By Day');
      await tapText(tester, 'Continue');
      expect(find.text('How Much Protein?'), findsWidgets);
      await tapText(tester, 'High');
      await tapText(tester, 'Continue');
      expect(find.text('Happy With This?'), findsWidgets);
      expect(find.text('Preferred diet: Keto'), findsOneWidget);
      expect(find.text('Day 7'), findsOneWidget);
      await tapText(tester, 'Continue');
      expect(find.byType(AppShell), findsOneWidget);
      final plan = await nutrition.watchDietPlan(uid).first;
      expect(plan?.preferredDiet, 'keto');
      expect(plan?.proteinIntake, 'high');
    });
  }

  testWidgets('a failed save says so and stays on the step', (tester) async {
    final failing = _FailingUsers(
      InMemoryUserRepository(
        users: {
          uid: stagingOnboardingProfile(
            OnboardingStep.healthDisclaimer,
            uid: uid,
            now: now,
          )!,
        },
      ),
    );
    await pumpAt(
      tester,
      OnboardingStep.healthDisclaimer,
      userRepository: failing,
    );
    for (final toggle in [
      find.byType(Switch).first,
      find.byType(Switch).last,
    ]) {
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
    }
    await tapText(tester, 'Continue');
    expect(find.text('Unable to Save Consent'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Do You Agree?'), findsWidgets);
  });

  for (final step in [
    OnboardingStep.completeAccountSetup,
    OnboardingStep.healthDisclaimer,
    OnboardingStep.goalSetting,
    OnboardingStep.gymProfileSetup,
    OnboardingStep.mesocycleSetup,
    OnboardingStep.customiseProgram,
  ]) {
    testWidgets('${step.value} lays out at the largest text size', (
      tester,
    ) async {
      await pumpAt(tester, step, textScale: 3.1);
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Onboarding progress'), findsOneWidget);
    });
  }

  testWidgets('the gym step names the gym, opens its equipment, and '
      'Continue makes it the usual gym and moves on', (tester) async {
    await pumpAt(tester, OnboardingStep.gymProfileSetup);
    await tester.enterText(find.byType(TextField).first, 'Home Gym');
    await tapText(tester, 'Continue');
    expect(find.byType(GymProfileView), findsOneWidget);
    await tapText(tester, 'Continue');

    final profile = await tester.runAsync(() => users.watchUser(uid).first);
    expect(profile?.submittedFavouriteGymProfileId, isNotNull);
    expect(find.byType(GymProfileView), findsNothing);
    expect(find.text('Build My Own'), findsOneWidget);
  });

  testWidgets('Build My Own designs a mesocycle and moves on', (tester) async {
    await pumpAt(tester, OnboardingStep.mesocycleSetup);
    await tapText(tester, 'Build My Own');
    await tester.enterText(find.byKey(const Key('NameProgram.name')), 'Mine');
    await tester.pumpAndSettle();
    await tapText(tester, 'Continue');
    await tapText(tester, 'Continue');
    // A rest day: Activate waits for exercises.
    expect(
      find.text('Add exercises to turn this rest day into a workout day.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('DefineWorkout.addExercise')));
    await tester.pumpAndSettle();
    final exercise = PrebuiltCatalogue.instance.exercises
        .map((e) => e.name)
        .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    await tapText(tester, exercise);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ProgramDesign.activate')));
    await tester.pumpAndSettle();

    final profile = await tester.runAsync(() => users.watchUser(uid).first);
    expect(profile?.submittedActiveMesocycleId, isNotNull);
    expect(find.text('Build My Own'), findsNothing);
  });

  testWidgets('account setup in feet and pounds', (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await pumpAt(tester, OnboardingStep.completeAccountSetup);
    await tester.enterText(find.byType(TextField).first, 'Sam');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Prefer not to say');
    expect(
      find.text('Your calorie estimate will be less accurate.'),
      findsOneWidget,
    );
    await tapText(tester, 'Continue');
    await tapText(tester, 'Continue');
    expect(find.text('5 ft'), findsOneWidget);
    await tapText(tester, 'Metric');
    expect(find.text('175 cm'), findsOneWidget);
    await tapText(tester, 'Imperial');
    await tapText(tester, 'Continue');
    expect(find.text('154 lb'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('How Tall Are You?'), findsWidgets);
  });
}

class _FailingUsers extends Mock implements UserRepository {
  new(this._inner);

  final UserRepository _inner;

  @override
  Stream<UserModel?> watchUser(String uid) => _inner.watchUser(uid);

  @override
  Future<void> updateUserFields(String uid, List<UserFieldValue> fields) =>
      Future.error(Exception('offline'));
}
