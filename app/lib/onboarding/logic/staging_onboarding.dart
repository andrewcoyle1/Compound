import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:user_repository/user_repository.dart';

/// A profile that resumes onboarding at [step], for exercising onboarding
/// in the staging flavor without tapping through the steps before it
/// (`--dart-define=STAGING_ONBOARDING=<step>`). Null for account setup and
/// earlier, which start from no profile at all, as a new account does.
///
/// The ids it names (goal, gym, mesocycle) point at nothing: each later
/// screen copes with a missing document.
UserModel? stagingOnboardingProfile(
  OnboardingStep step, {
  required String uid,
  required DateTime now,
}) {
  if (step.orderIndex <= OnboardingStep.completeAccountSetup.orderIndex) {
    return null;
  }
  bool reached(OnboardingStep later) => step.orderIndex > later.orderIndex;
  // The training steps run gym first, then program (`inferredOnboardingStep`).
  final pastGym =
      step == OnboardingStep.mesocycleSetup ||
      reached(OnboardingStep.gymProfileSetup);
  return UserModel(
    userId: uid,
    isAnonymous: true,
    creationDate: now,
    submittedFirstName: 'Sam',
    submittedGender: Gender.female,
    submittedDateOfBirth: DateTime(1994, 5, 17),
    submittedHeightCentimeters: 168,
    submittedLengthUnitPreference: LengthUnitPreference.centimeters,
    submittedWeightKilograms: 72,
    submittedWeightUnitPreference: WeightUnitPreference.kilograms,
    submittedExerciseFrequency: ExerciseFrequency.threeToFour,
    submittedDailyActivityLevel: ActivityLevel.moderate,
    acceptedHealthDisclaimerVersion: reached(OnboardingStep.healthDisclaimer)
        ? currentHealthDisclaimerVersion
        : null,
    submittedCurrentGoalId: reached(OnboardingStep.goalSetting)
        ? 'staging-goal'
        : null,
    submittedFavouriteGymProfileId: pastGym ? 'staging-gym' : null,
    submittedActiveMesocycleId:
        step.orderIndex >= OnboardingStep.customiseProgram.orderIndex
        ? 'staging-mesocycle'
        : null,
  );
}
