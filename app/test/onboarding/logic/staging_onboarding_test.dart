import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:compound/onboarding/logic/staging_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each staging profile resumes at the step it was made for', () {
    final now = DateTime(2026, 10, 15);
    for (final step in OnboardingStep.values) {
      final profile = stagingOnboardingProfile(step, uid: 'u', now: now);
      if (step.orderIndex <= OnboardingStep.completeAccountSetup.orderIndex) {
        expect(profile, isNull, reason: step.name);
        continue;
      }
      final expected = switch (step) {
        OnboardingStep.notifications ||
        OnboardingStep.healthData => OnboardingStep.healthDisclaimer,
        OnboardingStep.complete => OnboardingStep.customiseProgram,
        _ => step,
      };
      expect(inferredOnboardingStep(profile!), expected, reason: step.name);
    }
  });
}
