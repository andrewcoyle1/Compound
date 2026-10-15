import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_repository/user_repository.dart';

/// Mirrors `OnboardingStepInferenceTests`, `OnboardingStepRouterTests` and
/// `OnboardingStepProgressTests`.
void main() {
  UserModel user({
    bool dateOfBirth = true,
    bool gender = true,
    bool height = true,
    bool weight = true,
    bool frequency = true,
    bool activity = true,
    bool cardioFitness = true,
    String? disclaimerVersion = currentHealthDisclaimerVersion,
    String? goalId = 'goal-1',
    String? gymProfileId = 'gym-1',
    String? mesocycleId = 'program-1',
    bool finished = true,
  }) => UserModel(
    userId: 'user-1',
    submittedDateOfBirth: dateOfBirth ? DateTime.utc(1990) : null,
    submittedGender: gender ? Gender.female : null,
    submittedHeightCentimeters: height ? 170 : null,
    submittedWeightKilograms: weight ? 65 : null,
    submittedExerciseFrequency: frequency ? ExerciseFrequency.daily : null,
    submittedDailyActivityLevel: activity ? ActivityLevel.active : null,
    submittedCardioFitnessLevel: cardioFitness
        ? CardioFitnessLevel.intermediate
        : null,
    acceptedHealthDisclaimerVersion: disclaimerVersion,
    submittedCurrentGoalId: goalId,
    submittedFavouriteGymProfileId: gymProfileId,
    submittedActiveMesocycleId: mesocycleId,
    didCompleteOnboarding: finished,
  );

  group('inferredOnboardingStep', () {
    test('an empty profile starts at account setup', () {
      expect(
        inferredOnboardingStep(const UserModel(userId: 'user-1')),
        OnboardingStep.completeAccountSetup,
      );
    });

    test('any missing account detail returns to account setup', () {
      for (final missing in [
        user(dateOfBirth: false),
        user(gender: false),
        user(height: false),
        user(weight: false),
        user(frequency: false),
        user(activity: false),
      ]) {
        expect(
          inferredOnboardingStep(missing),
          OnboardingStep.completeAccountSetup,
        );
      }
    });

    test('a profile without cardio fitness is not sent back', () {
      expect(
        inferredOnboardingStep(user(cardioFitness: false)),
        OnboardingStep.complete,
      );
      expect(
        inferredOnboardingStep(
          user(cardioFitness: false, disclaimerVersion: null),
        ),
        OnboardingStep.healthDisclaimer,
      );
    });

    test('an unaccepted or superseded disclaimer resumes at the disclaimer, '
        'before the goal', () {
      expect(
        inferredOnboardingStep(user(disclaimerVersion: null)),
        OnboardingStep.healthDisclaimer,
      );
      expect(
        inferredOnboardingStep(user(disclaimerVersion: '2024.01.01')),
        OnboardingStep.healthDisclaimer,
      );
    });

    test('then goal, gym, program and the completion flag, in order', () {
      expect(
        inferredOnboardingStep(user(goalId: null)),
        OnboardingStep.goalSetting,
      );
      expect(
        inferredOnboardingStep(user(gymProfileId: null)),
        OnboardingStep.gymProfileSetup,
      );
      // A later step does not skip an earlier one.
      expect(
        inferredOnboardingStep(user(gymProfileId: null, mesocycleId: 'p')),
        OnboardingStep.gymProfileSetup,
      );
      expect(
        inferredOnboardingStep(user(mesocycleId: null)),
        OnboardingStep.mesocycleSetup,
      );
      expect(
        inferredOnboardingStep(user(finished: false)),
        OnboardingStep.customiseProgram,
      );
      expect(inferredOnboardingStep(user()), OnboardingStep.complete);
    });
  });

  group('onboardingRoute', () {
    test('auth, subscription and account setup land on account setup', () {
      for (final step in [
        OnboardingStep.auth,
        OnboardingStep.subscription,
        OnboardingStep.completeAccountSetup,
      ]) {
        expect(onboardingRoute(step), OnboardingRoute.accountSetup);
      }
    });

    test('a stored permission step resumes at the disclaimer', () {
      for (final step in [
        OnboardingStep.notifications,
        OnboardingStep.healthData,
        OnboardingStep.healthDisclaimer,
      ]) {
        expect(onboardingRoute(step), OnboardingRoute.healthDisclaimer);
      }
    });

    test('each later step has its own screen, and complete has none', () {
      expect(onboardingRoute(OnboardingStep.goalSetting), OnboardingRoute.goal);
      expect(
        onboardingRoute(OnboardingStep.gymProfileSetup),
        OnboardingRoute.gymProfile,
      );
      expect(
        onboardingRoute(OnboardingStep.mesocycleSetup),
        OnboardingRoute.program,
      );
      expect(
        onboardingRoute(OnboardingStep.customiseProgram),
        OnboardingRoute.diet,
      );
      expect(onboardingRoute(OnboardingStep.complete), isNull);
    });

    test('routes live under /onboarding', () {
      expect(OnboardingRoute.goal.path, '/onboarding/goal');
      expect(OnboardingRoute.goal.routeName, 'onboarding-goal');
    });
  });

  group('OnboardingStep', () {
    test('progress follows the order index', () {
      expect(OnboardingStep.auth.progress, 1 / 11);
      expect(OnboardingStep.goalSetting.progress, 7 / 11);
      expect(OnboardingStep.complete.progress, 1);
    });

    test('keeps the raw value the program step was stored under', () {
      expect(OnboardingStep.mesocycleSetup.value, 'trainingProgramSetup');
    });
  });
}
