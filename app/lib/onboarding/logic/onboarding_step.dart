import 'package:user_repository/user_repository.dart';

/// Where a user is in onboarding (Swift `OnboardingStep`, `UserModel.swift`).
/// [value] is the raw value Swift stores and logs.
enum OnboardingStep {
  auth('auth', 0),
  subscription('subscription', 1),
  completeAccountSetup('completeAccountSetup', 2),
  notifications('notifications', 3),
  healthData('healthData', 4),
  healthDisclaimer('healthDisclaimer', 5),
  goalSetting('goalSetting', 6),
  // The raw value keeps the name Swift stored and logged before the rename.
  mesocycleSetup('trainingProgramSetup', 7),
  gymProfileSetup('gymProfileSetup', 8),
  customiseProgram('customiseProgram', 9),
  complete('complete', 10);

  new(this.value, this.orderIndex);

  /// The raw value.
  final String value;

  /// Swift's `orderIndex`.
  final int orderIndex;

  /// How far through onboarding this step is, `0..1`, for the progress bar
  /// (`OnboardingStep.progress`).
  double get progress => (orderIndex + 1) / (complete.orderIndex + 1);
}

/// The health notices the app presents, and the versions an acceptance is
/// recorded against (`UserModel.currentHealthDisclaimerVersion`). Bumping
/// one sends everyone who accepted an earlier text back to the disclaimer.
const currentHealthDisclaimerVersion = '2025.10.05';

/// See [currentHealthDisclaimerVersion].
const currentHealthPrivacyPolicyVersion = '2025.10.05';

/// The step [user] resumes at, from which fields are filled
/// (`UserModel.inferredOnboardingStep`, `UserModel.swift:366-391`).
///
/// Cardio fitness is not required: onboarding stopped asking for it. The
/// disclaimer is compared against the current version, not merely checked
/// for presence.
OnboardingStep inferredOnboardingStep(UserModel user) {
  if (user.submittedDateOfBirth == null ||
      user.submittedGender == null ||
      user.submittedHeightCentimeters == null ||
      user.submittedWeightKilograms == null ||
      user.submittedExerciseFrequency == null ||
      user.submittedDailyActivityLevel == null) {
    return OnboardingStep.completeAccountSetup;
  }
  if (user.acceptedHealthDisclaimerVersion != currentHealthDisclaimerVersion) {
    return OnboardingStep.healthDisclaimer;
  }
  if (user.submittedCurrentGoalId == null) return OnboardingStep.goalSetting;
  if (user.submittedFavouriteGymProfileId == null) {
    return OnboardingStep.gymProfileSetup;
  }
  if (user.submittedActiveMesocycleId == null) {
    return OnboardingStep.mesocycleSetup;
  }
  if (!user.didCompleteOnboarding) return OnboardingStep.customiseProgram;
  return OnboardingStep.complete;
}

/// The onboarding screens, one route each. A screen's own questions (the
/// account-setup, goal and diet sub-screens) live inside its page.
enum OnboardingRoute {
  accountSetup('account'),
  healthDisclaimer('health-disclaimer'),
  goal('goal'),
  gymProfile('gym'),
  program('program'),
  diet('diet');

  new(this.segment);

  /// The path below [onboardingPath].
  final String segment;

  /// The route's full path.
  String get path => '$onboardingPath/$segment';

  /// The route's name.
  String get routeName => 'onboarding-$segment';
}

/// Every onboarding route starts here.
const onboardingPath = '/onboarding';

/// The screen that resumes onboarding at [step], or null for
/// [OnboardingStep.complete], which goes to the tabs: Swift's one
/// `OnboardingStepRouter.routeToOnboardingStep` switch.
///
/// Auth and subscription land on account setup, since whoever is routed here
/// is already signed in (the paywall waits for M4). The two retired
/// permission steps resume at the disclaimer, since a stored profile can
/// still name them.
OnboardingRoute? onboardingRoute(OnboardingStep step) => switch (step) {
  OnboardingStep.auth ||
  OnboardingStep.subscription ||
  OnboardingStep.completeAccountSetup => OnboardingRoute.accountSetup,
  OnboardingStep.notifications ||
  OnboardingStep.healthData ||
  OnboardingStep.healthDisclaimer => OnboardingRoute.healthDisclaimer,
  OnboardingStep.goalSetting => OnboardingRoute.goal,
  OnboardingStep.gymProfileSetup => OnboardingRoute.gymProfile,
  OnboardingStep.mesocycleSetup => OnboardingRoute.program,
  OnboardingStep.customiseProgram => OnboardingRoute.diet,
  OnboardingStep.complete => null,
};
