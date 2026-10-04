//
//  OnboardingStepRouter.swift
//  Compound
//
//  Six presenters each carried a byte-identical `route(to step: OnboardingStep)` switch:
//  Welcome, Auth, GoalSummary, Paywall, GymProfile and MesocycleDesign. They had already
//  drifted — AuthPresenter's copy sent `.mesocycleSetup` to the gym-profile screen.
//  The switch now lives here once so the copies cannot diverge again.
//

import SwiftUI

/// The onboarding destinations any screen that can resume onboarding needs to reach.
@MainActor
protocol OnboardingStepRouter: GlobalRouter {
    func showNamePhotoView()
    func showHealthDisclaimerView()
    func showOverarchingObjectiveView()
    func showCreateGymProfileView(delegate: CreateGymProfileDelegate)
    func showOnboardingMesocycleView(delegate: CreateMesocycleDelegate)
    func showCustomisingDietProgramView()
    func showOnboardingCompletedView()
}

extension OnboardingStepRouter {

    /// Navigates to the screen that resumes onboarding at `step`.
    ///
    /// `onComplete` is invoked by the gym-profile and training-mesocycle steps once the user
    /// finishes them, so the caller can re-infer where to go next.
    ///
    /// `.auth` and `.subscription` land on complete-account setup: by the time any of these
    /// screens is routing, the user is already signed in. `WelcomePresenter` is the one entry
    /// point that can still send someone to auth or the paywall, so it handles those two
    /// cases itself before delegating here.
    func routeToOnboardingStep(_ step: OnboardingStep, onComplete: @escaping @MainActor @Sendable () -> Void) {
        switch step {
        // Account setup and goal setting start on their first question: the "Ready to Begin?"
        // and "Ready to Set a Goal?" screens that only held a Continue button are gone.
        case .auth, .subscription, .completeAccountSetup:
            showNamePhotoView()

        // The two permission steps are gone: each permission is now asked for where it is first
        // used. The cases stay because a stored profile can still name them.
        case .notifications, .healthData, .healthDisclaimer:
            showHealthDisclaimerView()

        case .goalSetting:
            showOverarchingObjectiveView()

        case .gymProfileSetup:
            showCreateGymProfileView(delegate: CreateGymProfileDelegate(onComplete: { onComplete() }))

        case .mesocycleSetup:
            // `CreateMesocycleDelegate.onComplete` is `@Sendable` and may fire off the main
            // actor, so it is hopped explicitly — as each presenter's own copy did.
            showOnboardingMesocycleView(
                delegate: CreateMesocycleDelegate(onComplete: { Task { @MainActor in onComplete() } })
            )

        case .customiseProgram:
            showCustomisingDietProgramView()

        case .complete:
            showOnboardingCompletedView()
        }
    }
}
