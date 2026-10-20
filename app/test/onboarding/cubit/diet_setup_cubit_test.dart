import 'package:analytics_repository/analytics_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/onboarding/diet/diet_setup_cubit.dart';
import 'package:compound/onboarding/logic/diet_plan_builder.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:compound_models/compound_models.dart' show UserModelKeys;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';
import 'helpers.dart';

class _MockProgramRepository extends Mock implements ProgramRepository;

/// Mirrors `OnboardingDietChoicesPresenterTests`,
/// `OnboardingDietPlanPresenterTests` and `OnboardingFinishPresenterTests`.
void main() {
  late NutritionRepository nutrition;
  late ProgramRepository programs;
  late BodyRepository body;
  late UserRepository users;
  late RecordingAnalytics analytics;
  late List<String> calls;
  final now = DateTime.utc(2026, 10, 15, 9);
  final upperLower = copyMesocycle(
    PrebuiltCatalogue.instance.mesocycles.firstWhere(
      (m) => m.id == 'program-upper-lower',
    ),
    authorId: 'uid',
    now: now,
    newId: () => 'MESO',
  );
  final profile = UserModel(
    userId: 'uid',
    submittedGender: Gender.female,
    submittedWeightKilograms: 72,
    submittedHeightCentimeters: 168,
    submittedDateOfBirth: DateTime(1996, 10, 15),
    submittedDailyActivityLevel: ActivityLevel.moderate,
    submittedActiveMesocycleId: 'MESO',
    submittedCurrentGoalId: 'GOAL',
  );
  final goal = WeightGoal(
    goalId: 'GOAL',
    userId: 'uid',
    objective: OverarchingObjective.loseWeight,
    startingWeightKg: 72,
    targetWeightKg: 65,
    weeklyChangeKg: 0.4,
    createdAt: now,
    status: GoalStatus.active,
  );

  setUpAll(() {
    registerFallbackValue(<UserFieldValue>[]);
    registerFallbackValue(
      buildDietPlan(
        user: profile,
        choices: recommendedDietChoices(null),
        now: now,
      ),
    );
  });

  setUp(() {
    nutrition = MockNutritionRepository();
    programs = _MockProgramRepository();
    body = MockBodyRepository();
    users = MockUserRepository();
    analytics = RecordingAnalytics();
    calls = [];
    when(() => programs.watchMesocycles('uid'))
        .thenAnswer((_) => Stream.value([upperLower]));
    when(() => body.watchCurrentGoal('uid', currentGoalId: 'GOAL'))
        .thenAnswer((_) => Stream.value(goal));
    when(() => nutrition.watchDietPlan('uid'))
        .thenAnswer((_) => Stream.value(null));
    when(() => nutrition.saveDietPlan(any()))
        .thenAnswer((_) async => calls.add('saveDietPlan'));
    when(() => users.updateUserFields(any(), any()))
        .thenAnswer((_) async => calls.add('updateUserFields'));
  });

  DietSetupCubit build({UserModel? user, bool isFromSettings = false}) =>
      DietSetupCubit(
        nutritionRepository: nutrition,
        programRepository: programs,
        bodyRepository: body,
        userRepository: users,
        analyticsRepository: analytics.repository,
        profile: user ?? profile,
        isFromSettings: isFromSettings,
        now: () => now,
      );

  Future<DietSetupCubit> loaded({
    UserModel? user,
    bool isFromSettings = false,
  }) async {
    final cubit = build(user: user, isFromSettings: isFromSettings);
    await cubit.load();
    return cubit;
  }

  test('opens on the intro with Swift defaults', () async {
    final cubit = await loaded();
    expect(cubit.state.question, DietQuestion.intro);
    expect(cubit.state.diet, maths.PreferredDiet.balanced);
    expect(cubit.state.protein, maths.ProteinIntake.moderate);
    expect(cubit.state.distribution, isNull);
    expect(cubit.state.gender, Gender.female);
    expect(
      analytics.events.first.eventName,
      'CustomisingDietProgramView_Appear',
    );
    expect(analytics.events.first.parameters, isNull);
  });

  test('a plan already saved sets the answers it opens on', () async {
    when(() => nutrition.watchDietPlan('uid')).thenAnswer(
      (_) => Stream.value(
        buildDietPlan(
          user: profile,
          choices: (
            diet: maths.PreferredDiet.keto,
            distribution: maths.CalorieDistribution.even,
            protein: maths.ProteinIntake.high,
          ),
          now: now,
        ),
      ),
    );
    final cubit = await loaded();
    expect(cubit.state.diet, maths.PreferredDiet.keto);
    expect(cubit.state.distribution, maths.CalorieDistribution.even);
    expect(cubit.state.protein, maths.ProteinIntake.high);
  });

  test('reads fail quietly, as nothing to build on', () async {
    when(() => programs.watchMesocycles('uid'))
        .thenAnswer((_) => Stream.error(Exception('a')));
    when(() => body.watchCurrentGoal('uid', currentGoalId: 'GOAL'))
        .thenAnswer((_) => Stream.error(Exception('b')));
    when(() => nutrition.watchDietPlan('uid'))
        .thenAnswer((_) => Stream.error(Exception('c')));
    final cubit = await loaded();
    cubit.useRecommendedPlan();
    expect(cubit.state.plan?.trainingType, 'moderate');
    expect(cubit.state.mesocycleName, isNull);
  });

  test('the recommended plan uses the mesocycle split and the goal', () async {
    final cubit = await loaded();
    cubit.useRecommendedPlan();
    expect(cubit.state.question, DietQuestion.plan);
    final expected = buildDietPlan(
      user: profile,
      choices: (
        diet: maths.PreferredDiet.balanced,
        distribution: maths.CalorieDistribution.varied,
        protein: maths.ProteinIntake.moderate,
      ),
      now: now,
      goal: goal,
      mesocycle: upperLower,
    );
    expect(cubit.state.plan?.toFirestore(), expected.toFirestore());
    expect(
      (cubit.state.mesocycleName, cubit.state.trainingDaysPerWeek),
      ('Upper/Lower', 4),
    );
    expect(cubit.back(), isTrue);
    expect(cubit.state.question, DietQuestion.intro);
    expect(cubit.back(), isFalse);
    expect(analytics.names, contains('Onboarding_CustProgram_UseRecommended'));
  });

  test('customising asks diet, distribution (prefilled from the mesocycle) '
      'and protein', () async {
    final cubit = await loaded();
    cubit
      ..customize()
      ..dietSelected(maths.PreferredDiet.lowCarb)
      ..dietContinued();
    expect(cubit.state.question, DietQuestion.distribution);
    expect(cubit.state.distribution, maths.CalorieDistribution.varied);
    expect(analytics.last('Onboarding_CalDist_Prefilled').parameters, {
      'distribution': 'varied',
      'reason': 'training_days_4',
    });
    expect(
      analytics.last('Onboarding_CalDist_TrainingContextLoaded').parameters,
      {'daysPerWeek': 4},
    );
    cubit
      ..distributionSelected(maths.CalorieDistribution.even)
      ..distributionContinued()
      ..proteinSelected(maths.ProteinIntake.veryHigh)
      ..proteinContinued();
    expect(cubit.state.question, DietQuestion.plan);
    expect(cubit.state.plan?.preferredDiet, 'lowCarb');
    expect(cubit.state.plan?.calorieDistribution, 'even');
    expect(cubit.state.plan?.proteinIntake, 'veryHigh');
    expect(cubit.back(), isTrue);
    expect(cubit.state.question, DietQuestion.protein);
    expect(
      analytics.events
          .where((e) => e.type == LogType.info)
          .map((e) => e.eventName)
          .where((name) => name.endsWith('_Navigate')),
      [
        'Onboarding_CustProgram_Navigate',
        'Onboarding_PrefDiet_Navigate',
        'Onboarding_CalDist_Navigate',
        'Onboarding_ProteinIntake_Navigate',
      ],
    );
    expect(analytics.last('PreferredDietView_Appear').parameters, {
      'is_onboarding': true,
    });
  });

  test('without a mesocycle the distribution must be chosen', () async {
    final cubit = await loaded(user: const UserModel(userId: 'uid'));
    cubit
      ..customize()
      ..dietContinued();
    expect(cubit.state.distribution, isNull);
    cubit
      ..distributionContinued()
      ..proteinContinued();
    expect(cubit.state.question, DietQuestion.distribution);
  });

  test('warns when a day is below the resting calories', () async {
    final cubit = await loaded();
    cubit.useRecommendedPlan();
    expect(cubit.state.restingKcalAboveTarget, isNull);

    // Sedentary, at the fastest rate: the deficit is capped at a quarter,
    // and a varied week's low days fall under the resting 1,459 kcal.
    when(() => body.watchCurrentGoal('uid', currentGoalId: 'GOAL')).thenAnswer(
      (_) => Stream.value(
        WeightGoal(
          goalId: 'GOAL',
          userId: 'uid',
          objective: OverarchingObjective.loseWeight,
          startingWeightKg: 72,
          targetWeightKg: 60,
          weeklyChangeKg: 1.5,
          createdAt: now,
          status: GoalStatus.active,
        ),
      ),
    );
    final steep = await loaded(
      user: UserModel.fromFirestore({
        ...profile.toFirestore(),
        UserModelKeys.submittedDailyActivityLevel: 'sedentary',
      }),
    );
    steep.useRecommendedPlan();
    expect(steep.state.restingKcalAboveTarget, closeTo(1459, 1e-9));
  });

  group('save', () {
    test('saves the plan, then marks onboarding complete', () async {
      final cubit = await loaded();
      cubit.useRecommendedPlan();
      await cubit.save();
      expect(calls, ['saveDietPlan', 'updateUserFields']);
      final plan =
          verify(() => nutrition.saveDietPlan(captureAny())).captured.single
              as DietPlan;
      expect(plan.toFirestore(), cubit.state.plan?.toFirestore());
      final fields = verify(() => users.updateUserFields('uid', captureAny()))
          .captured;
      expect(fieldsOf(fields.single), {
        UserModelKeys.didCompleteOnboarding: true,
      });
      expect(cubit.state.status, DietSetupStatus.saved);
      expect(analytics.names.sublist(analytics.names.length - 3), [
        'DietView_SaveDietPlan_Start',
        'DietView_SaveDietPlan_Success',
        'DietView_Navigate',
      ]);
      await cubit.save();
      verifyNever(() => nutrition.saveDietPlan(any()));
    });

    test('a failed plan save leaves onboarding open, and says so', () async {
      when(() => nutrition.saveDietPlan(any())).thenThrow(Exception('x'));
      final cubit = await loaded();
      cubit.useRecommendedPlan();
      await cubit.save();
      verifyNever(() => users.updateUserFields(any(), any()));
      expect(cubit.state.status, DietSetupStatus.failure);
      expect(analytics.last('DietView_SaveDietPlan_Fail').type, LogType.severe);
    });

    test('nothing is saved before there is a plan', () async {
      final cubit = await loaded();
      await cubit.save();
      verifyNever(() => nutrition.saveDietPlan(any()));
      await cubit.close();
      expect(analytics.names.last, 'CustomisingDietProgramView_Disappear');
    });
  });

  // OnboardingDietChoicesPresenterTests' settings and floor cases,
  // OnboardingDietPlanPresenterTests' "Rebuilding From Settings Does Not
  // Enter Onboarding" and OnboardingSelectionHapticsTests' is_onboarding.
  group('from Settings', () {
    test(
      'opens on the diet, and its screens say they are not onboarding',
      () async {
        final cubit = await loaded(isFromSettings: true);
        expect(cubit.state.question, DietQuestion.preferredDiet);
        expect(cubit.state.isFromSettings, isTrue);
        expect(analytics.events.first.eventName, 'PreferredDietView_Appear');
        expect(analytics.events.first.parameters, {'is_onboarding': false});
        // The diet is the first question: back leaves the flow.
        expect(cubit.back(), isFalse);
        cubit.dietContinued();
        await cubit.close();
        for (final name in [
          'PreferredDietView_Disappear',
          'CalorieFloorView_Appear',
          'CalorieFloorView_Disappear',
        ]) {
          expect(analytics.last(name).parameters, {'is_onboarding': false});
        }
      },
    );

    test('the floor opens on the recommended one, and the chosen floor and '
        'the earlier diet are both carried', () async {
      final cubit = await loaded(isFromSettings: true);
      cubit
        ..dietSelected(maths.PreferredDiet.lowCarb)
        ..dietContinued();
      expect(cubit.state.question, DietQuestion.calorieFloor);
      expect(cubit.state.calorieFloor, standardCalorieFloor);
      expect(analytics.last('Onboarding_CalFloor_Prefilled').parameters, {
        'floor': 'standard',
        'reason': 'default',
      });
      cubit.calorieFloorContinued();
      expect(cubit.state.question, DietQuestion.distribution);
      expect(
        analytics.last('Onboarding_CalFloor_Navigate').parameters,
        <String, Object?>{},
      );
      expect(cubit.state.diet, maths.PreferredDiet.lowCarb);
      // Back from the distribution is the floor here, not the diet.
      expect(cubit.back(), isTrue);
      expect(cubit.state.question, DietQuestion.calorieFloor);
      expect(cubit.back(), isTrue);
      expect(cubit.state.question, DietQuestion.preferredDiet);
    });

    test('rebuilding a plan opens on its floor; the old low floor opens on '
        'the standard one', () async {
      DietPlan plan(String floor) => DietPlan.fromFirestore({
        ...buildDietPlan(
          user: profile,
          choices: recommendedDietChoices(null),
          now: now,
        ).toFirestore(),
        'calorieFloor': floor,
      });
      for (final (floor, reason) in [
        ('standard', 'current_plan'),
        ('low', 'default'),
      ]) {
        when(() => nutrition.watchDietPlan('uid'))
            .thenAnswer((_) => Stream.value(plan(floor)));
        final cubit = await loaded(isFromSettings: true);
        cubit.dietContinued();
        expect(cubit.state.calorieFloor, standardCalorieFloor);
        expect(
          analytics.last('Onboarding_CalFloor_Prefilled').parameters?['reason'],
          reason,
        );
      }
    });

    test('the floor can be picked again, but not continued without one', () {
      final cubit = build(isFromSettings: true)..calorieFloorContinued();
      expect(cubit.state.question, DietQuestion.preferredDiet);
      cubit.calorieFloorSelected(standardCalorieFloor);
      expect(cubit.state.calorieFloor, standardCalorieFloor);
    });

    test('rebuilding the plan saves it and leaves onboarding alone', () async {
      final cubit = await loaded(isFromSettings: true);
      cubit
        ..dietContinued()
        ..calorieFloorContinued()
        ..distributionContinued()
        ..proteinContinued();
      expect(cubit.state.question, DietQuestion.plan);
      await cubit.save();
      expect(calls, ['saveDietPlan']);
      verifyNever(() => users.updateUserFields(any(), any()));
      expect(cubit.state.status, DietSetupStatus.saved);
      expect(analytics.names.last, 'DietView_Navigate');
    });
  });

  test('onboarding skips the floor, both ways', () async {
    final cubit = await loaded();
    cubit
      ..customize()
      ..dietContinued();
    expect(cubit.state.question, DietQuestion.distribution);
    expect(analytics.names, isNot(contains('CalorieFloorView_Appear')));
    expect(cubit.back(), isTrue);
    expect(cubit.state.question, DietQuestion.preferredDiet);
    expect(cubit.back(), isTrue);
    expect(cubit.state.question, DietQuestion.intro);
  });
}
