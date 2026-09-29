//
//  OnboardingFinishPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
import AuthenticationServices
@testable import DialedIn

// The last two screens: connecting Strava, which is optional, and finishing, which is not.
//
// Finishing is the hop out of the onboarding module into the app. Until it happens the user is
// still inside onboarding, so anything that can leave this screen unable to complete strands
// somebody who has already answered every question.

// MARK: - Strava

/// Offered once, near the end. It is worth nothing if a user who does not want it — or whose
/// connection fails — cannot get past it.
@MainActor
struct OnboardingStravaConnectPresenterTests {

    private final class Interactor: SpyGlobalInteractor, StravaConnectInteractor {
        var stravaIsConnected: Bool = false
        var authenticateError: Error?
        private(set) var authenticateCount: Int = 0

        func stravaAuthenticate() async throws {
            authenticateCount += 1
            if let authenticateError {
                throw authenticateError
            }
            stravaIsConnected = true
        }
    }

    private final class Router: StravaConnectRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var alertTitles: [String] = []

        func showOnboardingCompletedView() { shown.append("onboardingCompleted") }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    private struct Screen {
        let presenter: StravaConnectPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(alreadyConnected: Bool = false) -> Screen {
        let interactor = Interactor()
        interactor.stravaIsConnected = alreadyConnected
        let router = Router()
        return Screen(
            presenter: StravaConnectPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    @Test("Test Opening The Screen Logs It As A Screen View")
    func testOpeningTheScreenLogsItAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["StravaConnect_Appear"])
        // A screen view is not an action, so nothing should land in the action log.
        #expect(screen.interactor.trackedEventNames.isEmpty)
    }

    /// The connected state is read straight off the manager rather than cached, so a user who
    /// authorised Strava on an earlier device sees the screen already satisfied.
    @Test("Test An Account Connected Earlier Shows As Connected")
    func testAnAccountConnectedEarlierShowsAsConnected() {
        #expect(makeScreen(alreadyConnected: true).presenter.isConnected)
        #expect(!makeScreen().presenter.isConnected)
    }

    /// Declining an optional integration must still finish onboarding.
    @Test("Test Skipping Strava Still Reaches The Last Screen")
    func testSkippingStravaStillReachesTheLastScreen() {
        let screen = makeScreen()

        screen.presenter.onSkipPressed()

        #expect(screen.router.shown == ["onboardingCompleted"])
        #expect(screen.interactor.authenticateCount == 0)
        #expect(screen.interactor.trackedEventNames == ["StravaConnect_Skip"])
    }

    @Test("Test Continuing After Connecting Reaches The Last Screen")
    func testContinuingAfterConnectingReachesTheLastScreen() {
        let screen = makeScreen()

        screen.presenter.onContinuePressed()

        #expect(screen.router.shown == ["onboardingCompleted"])
        #expect(screen.interactor.trackedEventNames == ["StravaConnect_Continue"])
    }

    @Test("Test Connecting Reports Success And Stops Spinning")
    func testConnectingReportsSuccessAndStopsSpinning() async {
        let screen = makeScreen()

        screen.presenter.onConnectPressed()
        // The spinner goes up on the same turn as the press, before the round trip starts.
        #expect(screen.presenter.isConnecting)

        #expect(await TestManagers.eventually { !screen.presenter.isConnecting })
        #expect(screen.presenter.isConnected)
        #expect(screen.interactor.trackedEventNames == ["StravaConnect_Connect_Success"])
        #expect(screen.router.alertTitles.isEmpty)
    }

    /// Authorising Strava is not finishing onboarding — the user still has to press Continue, so
    /// a successful connection must not move the screen on by itself.
    @Test("Test Connecting Does Not Navigate By Itself")
    func testConnectingDoesNotNavigateByItself() async {
        let screen = makeScreen()

        screen.presenter.onConnectPressed()

        #expect(await TestManagers.eventually { !screen.presenter.isConnecting })
        #expect(screen.router.shown.isEmpty)
    }

    /// A denied or cancelled OAuth round trip has to say so and hand the screen back: the spinner
    /// must stop, or the user is left looking at a button that can no longer be pressed.
    @Test("Test A Failed Connection Is Surfaced And Releases The Button")
    func testAFailedConnectionIsSurfacedAndReleasesTheButton() async {
        let screen = makeScreen()
        screen.interactor.authenticateError = URLError(.userAuthenticationRequired)

        screen.presenter.onConnectPressed()

        #expect(await TestManagers.eventually { !screen.router.alertTitles.isEmpty })
        #expect(screen.router.alertTitles == ["Strava Didn't Respond"])
        #expect(!screen.presenter.isConnecting)
        #expect(!screen.presenter.isConnected)
        #expect(screen.interactor.trackedEventNames == ["StravaConnect_Connect_Fail"])
    }

    /// Closing the OAuth sheet is a choice, not a failure — finding 12. It must not show an alert
    /// or log as a failure, and it still has to release the spinner.
    @Test("Test Cancelling The OAuth Sheet Is Silent")
    func testCancellingTheOAuthSheetIsSilent() async {
        let screen = makeScreen()
        screen.interactor.authenticateError = ASWebAuthenticationSessionError(.canceledLogin)

        screen.presenter.onConnectPressed()

        #expect(await TestManagers.eventually { !screen.presenter.isConnecting })
        #expect(screen.router.alertTitles.isEmpty)
        #expect(screen.interactor.trackedEventNames.isEmpty)
        #expect(!screen.presenter.isConnected)
    }

    /// And a user who declined at Strava's own screen is not trapped on the last optional step of
    /// onboarding: both ways out still work afterwards.
    @Test("Test A Failed Connection Does Not Block Finishing")
    func testAFailedConnectionDoesNotBlockFinishing() async {
        let screen = makeScreen()
        screen.interactor.authenticateError = URLError(.userAuthenticationRequired)
        screen.presenter.onConnectPressed()
        #expect(await TestManagers.eventually { !screen.router.alertTitles.isEmpty })

        screen.presenter.onSkipPressed()

        #expect(screen.router.shown == ["onboardingCompleted"])
    }

    /// A second attempt after a refusal has to actually reach Strava again rather than be
    /// swallowed by a spinner that was never lowered.
    @Test("Test Retrying After A Refusal Can Still Connect")
    func testRetryingAfterARefusalCanStillConnect() async {
        let screen = makeScreen()
        screen.interactor.authenticateError = URLError(.userAuthenticationRequired)
        screen.presenter.onConnectPressed()
        #expect(await TestManagers.eventually { !screen.router.alertTitles.isEmpty })

        screen.interactor.authenticateError = nil
        screen.presenter.onConnectPressed()

        #expect(await TestManagers.eventually { screen.presenter.isConnected })
        #expect(screen.interactor.authenticateCount == 2)
        #expect(!screen.presenter.isConnecting)
    }
}

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
