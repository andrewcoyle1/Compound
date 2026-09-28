//
//  OnboardingStepRouter.swift
//  DialedIn
//
//  Six presenters each carried a byte-identical `route(to step: OnboardingStep)` switch:
//  Welcome, Auth, GoalSummary, Paywall, GymProfile and ProgramDesign. They had already
//  drifted — AuthPresenter's copy sent `.trainingProgramSetup` to the gym-profile screen.
//  The switch now lives here once so the copies cannot diverge again.
//

import SwiftUI

/// The onboarding destinations any screen that can resume onboarding needs to reach.
@MainActor
protocol OnboardingStepRouter: GlobalRouter {
    func showCompleteAccountSetupView()
    func showHealthDisclaimerView()
    func showGoalSettingView()
    func showCreateGymProfileView(delegate: CreateGymProfileDelegate)
    func showOnboardingTrainingProgramView(delegate: CreateProgramDelegate)
    func showCustomisingDietProgramView()
    func showOnboardingCompletedView()
}

extension OnboardingStepRouter {

    /// Navigates to the screen that resumes onboarding at `step`.
    ///
    /// `onComplete` is invoked by the gym-profile and training-program steps once the user
    /// finishes them, so the caller can re-infer where to go next.
    ///
    /// `.auth` and `.subscription` land on complete-account setup: by the time any of these
    /// screens is routing, the user is already signed in. `WelcomePresenter` is the one entry
    /// point that can still send someone to auth or the paywall, so it handles those two
    /// cases itself before delegating here.
    func routeToOnboardingStep(_ step: OnboardingStep, onComplete: @escaping @MainActor @Sendable () -> Void) {
        switch step {
        case .auth, .subscription, .completeAccountSetup:
            showCompleteAccountSetupView()

        // The two permission steps are gone: each permission is now asked for where it is first
        // used. The cases stay because a stored profile can still name them.
        case .notifications, .healthData, .healthDisclaimer:
            showHealthDisclaimerView()

        case .goalSetting:
            showGoalSettingView()

        case .gymProfileSetup:
            showCreateGymProfileView(delegate: CreateGymProfileDelegate(onComplete: { onComplete() }))

        case .trainingProgramSetup:
            // `CreateProgramDelegate.onComplete` is `@Sendable` and may fire off the main
            // actor, so it is hopped explicitly — as each presenter's own copy did.
            showOnboardingTrainingProgramView(
                delegate: CreateProgramDelegate(onComplete: { Task { @MainActor in onComplete() } })
            )

        case .customiseProgram:
            showCustomisingDietProgramView()

        case .complete:
            showOnboardingCompletedView()
        }
    }
}
