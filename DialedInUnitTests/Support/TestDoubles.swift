//
//  TestDoubles.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Foundation
import SwiftUI
import SwiftfulRouting
@testable import DialedIn

/// Scaffolding for testing presenters.
///
/// A presenter takes an interactor and a router, both screen-specific protocols that `CoreInteractor`
/// and `CoreRouter` conform to. Neither of those can be built in a test — `CoreRouter` needs a live
/// `AnyRouter` from the view hierarchy — so each screen gets a small double instead.
///
/// `GlobalRouter` only requires one property, `router: AnyRouter`, and SwiftfulRouting publishes a
/// mock one through `RouterEnvironmentKey.defaultValue`. That is what makes this cheap: a router
/// double is its navigation methods recording what they were asked to do, and nothing else.

/// The mock `AnyRouter` the package uses for previews. Navigating through it does nothing.
@MainActor
enum TestRouting {
    static var anyRouter: AnyRouter { RouterEnvironmentKey.defaultValue }
}

/// Records the analytics and haptics every interactor inherits, so a test can assert a screen
/// logged what it should without a `LogManager`.
@MainActor
class SpyGlobalInteractor: GlobalInteractor {
    private(set) var trackedEventNames: [String] = []
    private(set) var trackedScreenEventNames: [String] = []
    private(set) var playedHaptics: [HapticOption] = []

    func trackEvent(eventName: String, parameters: [String: Any]?, type: LogType) {
        trackedEventNames.append(eventName)
    }

    func trackEvent(event: AnyLoggableEvent) {
        trackedEventNames.append(event.eventName)
    }

    func trackEvent(event: LoggableEvent) {
        trackedEventNames.append(event.eventName)
    }

    func trackScreenEvent(event: LoggableEvent) {
        trackedScreenEventNames.append(event.eventName)
    }

    func playHaptic(option: HapticOption) {
        playedHaptics.append(option)
    }

    /// Every toast raised, in order — the app-level ones a presenter puts up after its own screen
    /// has gone.
    private(set) var shownToasts: [AppToast] = []

    func showAppToast(_ toast: AppToast) {
        shownToasts.append(toast)
    }

    /// Set to take the screen offline: `ensureOnline(or:)` then shows the offline alert.
    var isOffline = false
}

/// The onboarding destinations, recorded rather than shown.
///
/// `OnboardingStepRouter` is adopted by six screens that can resume onboarding, and its nine
/// methods are the same nine every time. Subclass this and add the screen's own destinations.
@MainActor
class SpyOnboardingRouter: OnboardingStepRouter {
    let router: AnyRouter = TestRouting.anyRouter
    private(set) var shown: [String] = []

    /// The alerts, recorded here rather than in each subclass.
    ///
    /// The conformance to `GlobalRouter` is declared on *this* class, so the witness for the three
    /// alert methods is bound here once. A subclass that declares its own `showAlert` does not
    /// replace that witness — the protocol's default implementation still runs, and the alert
    /// escapes to the real router unseen. Intercepting them has to happen on this class.
    private(set) var alertTitles: [String] = []
    private(set) var alertedErrors: [Error] = []

    func showAlert(error: Error) { alertedErrors.append(error) }

    func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
        alertTitles.append(title)
    }

    func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }

    /// Records a destination. Subclasses call this from their own navigation methods so every
    /// screen a test drives through lands in one list, in order.
    func record(_ destination: String) {
        shown.append(destination)
    }

    func showCompleteAccountSetupView() { record("completeAccountSetup") }
    func showNotificationsPermissionsView() { record("notifications") }
    func showOnboardingHealthDataView() { record("healthData") }
    func showHealthDisclaimerView() { record("healthDisclaimer") }
    func showGoalSettingView() { record("goalSetting") }
    func showCreateGymProfileView(delegate: CreateGymProfileDelegate) { record("gymProfileSetup") }
    func showOnboardingTrainingProgramView(delegate: CreateProgramDelegate) { record("trainingProgramSetup") }
    func showCustomisingDietProgramView() { record("customisingDietProgram") }
    func showOnboardingCompletedView() { record("onboardingCompleted") }
}
