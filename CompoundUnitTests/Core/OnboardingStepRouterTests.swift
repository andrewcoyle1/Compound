//
//  OnboardingStepRouterTests.swift
//  CompoundUnitTests
//

import Testing
@testable import Compound

/// The notifications and Apple Health steps were removed from onboarding, but `OnboardingStep`
/// keeps both cases because a stored profile can still name them.
@MainActor
struct OnboardingStepRouterTests {

    @Test("A stored permission step resumes at the disclaimer", arguments: [OnboardingStep.notifications, .healthData])
    func testAStoredPermissionStepResumesAtTheDisclaimer(step: OnboardingStep) {
        let router = SpyOnboardingRouter()

        router.routeToOnboardingStep(step, onComplete: { })

        // Neither screen exists any more. Landing anywhere later would skip the disclaimer.
        #expect(router.shown == ["healthDisclaimer"])
    }
}
