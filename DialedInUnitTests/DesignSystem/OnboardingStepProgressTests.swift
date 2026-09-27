//
//  OnboardingStepProgressTests.swift
//  DialedInUnitTests
//
//  Pins `OnboardingStep.progress`, which `OnboardingStepScaffold` draws as its progress bar.
//

import Testing
@testable import DialedIn

struct OnboardingStepProgressTests {

    @Test func firstStepIsOneStepIn() {
        #expect(OnboardingStep.auth.progress == 1.0 / 11.0)
    }

    @Test func middleStepFollowsOrderIndex() {
        #expect(OnboardingStep.goalSetting.progress == 7.0 / 11.0)
    }

    @Test func lastStepIsComplete() {
        #expect(OnboardingStep.complete.progress == 1.0)
    }
}
