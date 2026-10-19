import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/expenditure/expenditure.dart';
import 'package:compound/onboarding/goal/goal_setup_cubit.dart';
import 'package:compound/onboarding/view/goal_setup_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../helpers/helpers.dart';

/// Changing the goal and the diet plan after onboarding, end to end on the
/// staging flavor's in-memory data: edit the running goal's rate from
/// Settings, start a new goal from Goal Progress, rebuild the plan from
/// Settings, and create one from the Progress tab's target grid.
void main() {
  const uid = StagingData.uid;
  final today = DateTime.now();
  final now = DateTime(today.year, today.month, today.day, 12);

  late StagingData data;

  Widget app() => App(
    socialRepository: emptySocialRepository(),
    coachRepository: silentCoachRepository(),
    purchasesRepository: FakePurchasesRepository(),
    authRepository: InMemoryAuthRepository(
      user: InMemoryAuthRepository.sampleUser,
    ),
    userRepository: data.users,
    workoutSessionRepository: InMemoryWorkoutSessionRepository(
      sessions: const [],
    ),
    nutritionRepository: data.nutrition,
    bodyRepository: data.body,
    programRepository: data.programs,
    trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
    checkInRepository: data.checkIns,
    proposalDismissals: ProposalDismissals(),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> start(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await settle(tester);
    GoRouter.of(tester.element(find.byType(Navigator).first)).go(location);
    await settle(tester);
  }

  Future<WeightGoal?> goal([String? id]) =>
      data.body.watchCurrentGoal(uid, currentGoalId: id).first;

  Future<DietPlan?> plan() => data.nutrition.watchDietPlan(uid).first;

  setUp(() => data = StagingData(now: now));

  testWidgets("edits the running goal's rate from Settings, keeping where it "
      'started, and the plan follows', (tester) async {
    final before = (await tester.runAsync(goal))!;
    final planBefore = (await tester.runAsync(plan))!;
    await start(tester, '/profile/settings');
    expect(find.text('Lose weight'), findsOneWidget);

    await tap(tester, find.text('Weight Goal'));
    await tap(tester, find.text('Edit Goal'));
    expect(find.text('What Is Your Goal?'), findsWidgets);
    expect(find.text('Choose one'), findsOneWidget);
    await tap(tester, find.text('Continue'));
    expect(find.text("What's Your Target?"), findsWidgets);
    await tap(tester, find.text('Continue'));
    expect(find.text('At What Rate?'), findsWidgets);
    final cubit = tester
        .element(find.byType(GoalSetupView))
        .read<GoalSetupCubit>();
    // Opens on the goal's own rate.
    expect(cubit.state.rateKg, before.weeklyChangeKg);
    cubit.rateChanged(0.5);
    await tester.pump();
    await tap(tester, find.text('Continue'));
    expect(find.text('Does This Look Right?'), findsWidgets);
    await tap(tester, find.text('Complete'));

    // Back on Settings.
    expect(find.text('Weight Goal'), findsOneWidget);
    final after = (await tester.runAsync(goal))!;
    expect(after.goalId, before.goalId);
    expect(after.weeklyChangeKg, 0.5);
    expect(after.targetWeightKg, before.targetWeightKg);
    expect(after.startingWeightKg, before.startingWeightKg);
    expect(after.createdAt, before.createdAt);
    final planAfter = (await tester.runAsync(plan))!;
    expect(planAfter.preferredDiet, planBefore.preferredDiet);
    expect(
      planAfter.days.first.calories,
      isNot(planBefore.days.first.calories),
    );
  });

  testWidgets('starts a new goal from Goal Progress; the old one is '
      'abandoned and the screen follows the new one', (tester) async {
    await start(tester, '/progress/goal-progress');
    expect(find.text('Lose weight'), findsOneWidget);

    await tap(tester, find.byTooltip('Change Goal'));
    await tap(tester, find.text('Start a New Goal'));
    await tap(tester, find.text('Maintain'));
    await tap(tester, find.text('Continue'));
    expect(find.text('Does This Look Right?'), findsWidgets);
    await tap(tester, find.text('Complete'));

    expect(find.text('Maintain'), findsOneWidget);
    expect((await tester.runAsync(goal))!.status, GoalStatus.abandoned);
    final user = (await tester.runAsync(
      () => data.users.watchUser(uid).first,
    ))!;
    final fresh = (await tester.runAsync(
      () => goal(user.submittedCurrentGoalId),
    ))!;
    expect(fresh.goalId, isNot(uid));
    expect(fresh.objective, OverarchingObjective.maintain);
    expect(fresh.status, GoalStatus.active);
  });

  testWidgets('rebuilds the plan from Settings, asking the floor', (
    tester,
  ) async {
    await start(tester, '/profile/settings');
    await tap(tester, find.text('Nutrition Plan'));
    expect(find.text("What's Your Diet?"), findsWidgets);
    await tap(tester, find.text('Keto'));
    await tap(tester, find.text('Continue'));
    expect(find.text("What's Your Floor?"), findsWidgets);
    expect(find.text('Standard Floor'), findsOneWidget);
    await tap(tester, find.text('Continue'));
    expect(find.text('Even or Varied?'), findsWidgets);
    await tap(tester, find.text('Continue'));
    expect(find.text('How Much Protein?'), findsWidgets);
    await tap(tester, find.text('Continue'));
    expect(find.text('Happy With This?'), findsWidgets);
    await tap(tester, find.text('Continue'));

    expect(find.text('Nutrition Plan'), findsOneWidget);
    expect((await tester.runAsync(plan))!.preferredDiet, 'keto');
  });

  testWidgets("creates a plan from the Progress tab's target grid", (
    tester,
  ) async {
    data = StagingData(now: now, withPlan: false);
    await start(tester, '/progress');
    expect(find.text('No Diet Plan'), findsOneWidget);

    await tap(tester, find.text('Create Diet Plan'));
    for (var i = 0; i < 5; i++) {
      await tap(tester, find.text('Continue'));
    }

    expect(find.text('No Diet Plan'), findsNothing);
    expect(await tester.runAsync(plan), isNotNull);
  });
}
