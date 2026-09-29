//
//  OnboardingFinishPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

// The last screen: finishing. (Connecting Strava used to come first; it left onboarding for
// Profile > Integrations, decision 11d, and its suite went with it.)
//
// Finishing is the hop out of the onboarding module into the app. Until it happens the user is
// still inside onboarding, so anything that can leave this screen unable to complete strands
// somebody who has already answered every question.

// MARK: - Finishing

/// The Continue button that ends onboarding. It marks the profile complete and then swaps the
/// onboarding module for the app itself.
///
/// The retry behaviour on the failure path — the flag that used to strand the user — has its own
/// suite in `OnboardingCompletedRetryTests`. What is left here is the ordering the button relies
/// on and what it logs.
@MainActor
struct OnboardingCompletedFinishButtonTests {

    private final class Interactor: SpyGlobalInteractor, OnboardingCompletedInteractor {
        var saveError: Error?
        private(set) var saveCount: Int = 0

        func saveOnboardingComplete() async throws {
            saveCount += 1
            if let saveError {
                throw saveError
            }
        }
    }

    private final class Router: OnboardingCompletedRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var alertedErrors: [Error] = []

        // The test target builds without `-DDEV`, so this is declared unguarded.
        func showDevSettingsView() { shown.append("devSettings") }
        func switchToCoreModule() { shown.append("coreModule") }
        func showAlert(error: Error) { alertedErrors.append(error) }
    }

    private struct Screen {
        let presenter: OnboardingCompletedPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: OnboardingCompletedPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// The button disables itself on the same turn it is pressed, before the save has begun.
    /// If that were deferred into the task, a double tap would start two saves.
    @Test("Test The Button Disables Itself Before The Save Begins")
    func testTheButtonDisablesItselfBeforeTheSaveBegins() {
        let screen = makeScreen()

        screen.presenter.onFinishButtonPressed()

        #expect(screen.presenter.isCompletingProfileSetup)
        // The save runs in a detached task, so nothing has happened yet on this turn.
        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.saveCount == 0)
    }

    /// The start event is logged synchronously and the outcome afterwards, so a funnel built on
    /// these two can tell a finish that was attempted from one that landed.
    @Test("Test Finishing Logs The Attempt Then The Outcome")
    func testFinishingLogsTheAttemptThenTheOutcome() async {
        let screen = makeScreen()

        screen.presenter.onFinishButtonPressed()
        #expect(screen.interactor.trackedEventNames == ["OnboardingCompletedView_Finish_Start"])

        #expect(await TestManagers.eventually { screen.router.shown == ["coreModule"] })
        #expect(screen.interactor.trackedEventNames == [
            "OnboardingCompletedView_Finish_Start",
            "OnboardingCompletedView_Finish_Success"
        ])
    }

    /// A save that fails must not be mistaken for one that worked: the user would be dropped into
    /// the app with a profile that still says onboarding is unfinished, and sent back round.
    @Test("Test A Failed Finish Never Enters The App")
    func testAFailedFinishNeverEntersTheApp() async {
        let screen = makeScreen()
        screen.interactor.saveError = URLError(.notConnectedToInternet)

        screen.presenter.onFinishButtonPressed()

        #expect(await TestManagers.eventually { !screen.router.alertedErrors.isEmpty })
        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.trackedEventNames == [
            "OnboardingCompletedView_Finish_Start",
            "OnboardingCompletedView_Finish_Fail"
        ])
    }
}
