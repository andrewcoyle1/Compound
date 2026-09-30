//
//  OnboardingAuthPresenterTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// Signing in — the one screen every user passes through, and the one place where a half-finished
/// attempt strands somebody outside the app entirely.
///
/// Two things happen here and they fail independently: authenticating with Apple or Google, and
/// then logging that identity into the app's own managers. In both cases the screen has to end up
/// somewhere the user can act from, never back on the sign-in buttons with the spinner gone and
/// nothing to show for it.
@MainActor
struct OnboardingAuthPresenterTests {

    /// The provider said no. Apple reports a cancelled sheet as an error like any other, so this
    /// stands in for both "the user changed their mind" and "the network was down".
    private struct AuthFailure: Error { }

    private final class Interactor: SpyGlobalInteractor, AuthInteractor {
        var currentUser: UserModel?
        var isPremium: Bool = false

        /// What the managers hold once `logIn` has run. Nothing is signed in before that, so the
        /// profile is applied on the way out of `logIn` rather than set up front.
        var userAfterLogin: UserModel?

        var appleResult: Result<(user: UserAuthInfo, isNewUser: Bool), Error> = .success((UserAuthInfo(uid: "user-1"), false))
        var googleResult: Result<(user: UserAuthInfo, isNewUser: Bool), Error> = .success((UserAuthInfo(uid: "user-1"), false))
        var logInError: Error?

        private(set) var logInCalls: [(uid: String, isNewUser: Bool)] = []

        func signInApple() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
            try appleResult.get()
        }

        func signInGoogle() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
            try googleResult.get()
        }

        func logIn(user: UserAuthInfo, isNewUser: Bool) async throws {
            if let logInError {
                throw logInError
            }
            logInCalls.append((user.uid, isNewUser))
            currentUser = userAfterLogin
        }
    }

    /// Auth can reach every onboarding step as well as its own three destinations.
    ///
    /// The alerts are recorded by `SpyOnboardingRouter`, which is where the `GlobalRouter`
    /// conformance is declared and therefore the only place they can be intercepted.
    /// `showLoadingModal` and `dismissModal` are extension-only and dispatch statically, so the
    /// spinner is not observable — these tests assert where the user ended up instead.
    private final class Router: SpyOnboardingRouter, AuthRouter {
        // The test target builds without `-DDEV`, but the app module it imports does not, so the
        // requirement is present and has to be satisfied unguarded.
        func showDevSettingsView() { record("devSettings") }
        func showPaywall(isOnboarding: Bool) { record("paywall(onboarding: \(isOnboarding))") }
        func showSubscriptionView() { record("subscription") }
        func switchToCoreModule() { record("coreModule") }
    }

    private struct Screen {
        let presenter: AuthPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: AuthPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - Signing in with Apple

    /// The whole point of the button: the identity Apple returns is handed on to the app's own
    /// login, carrying whether this is a brand new account.
    @Test("Apple sign in hands the identity to the app's login")
    func testAppleSignInLogsTheIdentityIntoTheApp() async {
        let screen = makeScreen()
        screen.interactor.appleResult = .success((UserAuthInfo(uid: "apple-user"), true))
        screen.interactor.userAfterLogin = onboardingStageUser(upTo: .completeAccountSetup, userId: "apple-user")

        screen.presenter.onSignInApplePressed()

        #expect(await TestManagers.eventually { !screen.interactor.logInCalls.isEmpty })
        #expect(screen.interactor.logInCalls.first?.uid == "apple-user")
        // `isNewUser` decides whether the user is sent through onboarding, so it has to survive
        // the hop from the provider to the app's own login.
        #expect(screen.interactor.logInCalls.first?.isNewUser == true)
    }

    /// A failed sign-in has to say so. Dismissing the spinner and leaving the screen exactly as it
    /// was would look to the user like the button does nothing at all.
    @Test("A failed Apple sign in surfaces an alert")
    func testAFailedAppleSignInIsSurfaced() async {
        let screen = makeScreen()
        screen.interactor.appleResult = .failure(AuthFailure())

        screen.presenter.onSignInApplePressed()

        #expect(await TestManagers.eventually { !screen.router.alertTitles.isEmpty })
        #expect(screen.router.alertTitles == ["Error Signing in with Apple"])
    }

    /// Cancelling the Apple sheet must leave the user where they were: not logged in, not routed
    /// onwards, and free to press the button again.
    @Test("A cancelled Apple sign in leaves the user signed out and on the screen")
    func testACancelledAppleSignInLeavesTheUserSignedOut() async {
        let screen = makeScreen()
        screen.interactor.appleResult = .failure(CancellationError())

        screen.presenter.onSignInApplePressed()

        #expect(await TestManagers.eventually { !screen.router.alertTitles.isEmpty })
        #expect(screen.interactor.logInCalls.isEmpty)
        #expect(screen.router.shown.isEmpty)
        #expect(screen.presenter.didTriggerLogin == false)
    }

    /// The sequence is what the sign-in funnel is read from: a start with no matching success is
    /// how a broken provider shows up in the numbers.
    @Test("Apple sign in tracks start then success, then the login's own pair")
    func testAppleSignInTracksStartThenSuccess() async {
        let screen = makeScreen()
        screen.interactor.userAfterLogin = onboardingStageUser(upTo: .completeAccountSetup)

        screen.presenter.onSignInApplePressed()

        #expect(await TestManagers.eventually { screen.interactor.trackedEventNames.contains("Auth_UserLogin_Success") })
        #expect(screen.interactor.trackedEventNames.prefix(4) == [
            "Auth_AppleAuth_Start",
            "Auth_AppleAuth_Success",
            "Auth_UserLogin_Start",
            "Auth_UserLogin_Success"
        ])
    }

    /// A sign-in that failed must never be counted as one that worked, or the funnel reports a
    /// provider outage as a healthy conversion.
    @Test("A failed Apple sign in is not tracked as a success")
    func testAFailedAppleSignInIsNotTrackedAsASuccess() async {
        let screen = makeScreen()
        screen.interactor.appleResult = .failure(AuthFailure())

        screen.presenter.onSignInApplePressed()

        #expect(await TestManagers.eventually { !screen.router.alertTitles.isEmpty })
        #expect(screen.interactor.trackedEventNames.contains("Auth_AppleAuth_Start"))
        #expect(!screen.interactor.trackedEventNames.contains("Auth_AppleAuth_Success"))
        #expect(!screen.interactor.trackedEventNames.contains("Auth_UserLogin_Start"))
    }

    /// The alert tells the user; the event tells us. Without it a provider outage looks in the
    /// numbers exactly like a screen nobody happened to use, because the only trace left of a
    /// failed attempt is a start event with nothing after it.
    @Test("A failed Apple sign in is recorded as a failure")
    func testAFailedAppleSignInIsRecordedAsAFailure() async {
        let screen = makeScreen()
        screen.interactor.appleResult = .failure(AuthFailure())

        screen.presenter.onSignInApplePressed()

        #expect(await TestManagers.eventually { screen.interactor.trackedEventNames.contains("Auth_AppleAuth_Fail") })
    }

    // MARK: - Signing in with Google

    @Test("Google sign in hands the identity to the app's login")
    func testGoogleSignInLogsTheIdentityIntoTheApp() async {
        let screen = makeScreen()
        screen.interactor.googleResult = .success((UserAuthInfo(uid: "google-user"), false))
        screen.interactor.userAfterLogin = onboardingStageUser(upTo: .complete, userId: "google-user")

        screen.presenter.onSignInGooglePressed()

        #expect(await TestManagers.eventually { !screen.interactor.logInCalls.isEmpty })
        #expect(screen.interactor.logInCalls.first?.uid == "google-user")
        #expect(screen.interactor.trackedEventNames.prefix(2) == ["Auth_GoogleAuth_Start", "Auth_GoogleAuth_Success"])
    }

    /// The two providers fail independently, and the message has to name the one that failed or
    /// the user retries the wrong button.
    @Test("A failed Google sign in names Google in the alert")
    func testAFailedGoogleSignInNamesGoogle() async {
        let screen = makeScreen()
        screen.interactor.googleResult = .failure(AuthFailure())

        screen.presenter.onSignInGooglePressed()

        #expect(await TestManagers.eventually { !screen.router.alertTitles.isEmpty })
        #expect(screen.router.alertTitles == ["Error Signing in with Google"])
        #expect(screen.interactor.logInCalls.isEmpty)
    }

    @Test("A failed Google sign in is recorded as a failure")
    func testAFailedGoogleSignInIsRecordedAsAFailure() async {
        let screen = makeScreen()
        screen.interactor.googleResult = .failure(AuthFailure())

        screen.presenter.onSignInGooglePressed()

        #expect(await TestManagers.eventually { screen.interactor.trackedEventNames.contains("Auth_GoogleAuth_Fail") })
    }

    // MARK: - Where the user lands afterwards

    /// The subscription gate is ahead of every other destination, including this one.
    ///
    /// This is a premium app, so finishing onboarding is not a permanent pass into it. A user who
    /// completed onboarding while subscribed and has since lapsed used to match the returning-user
    /// branch above the premium check and be let straight in, free, on every single sign-in.
    @Test("A returning user whose subscription has lapsed is sent to the subscription page")
    func testALapsedReturningUserIsSentToTheSubscriptionPage() async {
        let screen = makeScreen()
        screen.interactor.isPremium = false
        screen.interactor.userAfterLogin = onboardingStageUser(upTo: .complete)

        screen.presenter.handleOnAuthSuccess(user: UserAuthInfo(uid: "user-1"), isNewUser: false)

        #expect(await TestManagers.eventually { !screen.router.shown.isEmpty })
        #expect(screen.router.shown == ["subscription"])
        #expect(screen.interactor.trackedEventNames.contains("Auth_PaywallShownAfterLogin"))
    }

    /// A returning user with a finished account has no onboarding left to do.
    @Test("A returning user with a finished profile goes straight to the app")
    func testAReturningFinishedUserGoesStraightToTheApp() async {
        let screen = makeScreen()
        screen.interactor.isPremium = true
        screen.interactor.userAfterLogin = onboardingStageUser(upTo: .complete)

        screen.presenter.handleOnAuthSuccess(user: UserAuthInfo(uid: "user-1"), isNewUser: false)

        #expect(await TestManagers.eventually { !screen.router.shown.isEmpty })
        #expect(screen.router.shown == ["coreModule"])
    }

    /// A brand new account without a subscription is shown what the subscription is before being
    /// asked for the rest of their profile.
    @Test("A new user without a subscription sees the subscription screen")
    func testANewUserWithoutASubscriptionSeesTheSubscriptionScreen() async {
        let screen = makeScreen()
        screen.interactor.isPremium = false
        screen.interactor.userAfterLogin = onboardingStageUser(upTo: .completeAccountSetup)

        screen.presenter.handleOnAuthSuccess(user: UserAuthInfo(uid: "user-1"), isNewUser: true)

        #expect(await TestManagers.eventually { !screen.router.shown.isEmpty })
        #expect(screen.router.shown == ["subscription"])
        #expect(screen.interactor.trackedEventNames.contains("Auth_PaywallShownAfterLogin"))
    }

    /// Someone who subscribed and then quit half way through the questions comes back to the
    /// question they stopped at — not to the beginning, and not into an app they have not set up.
    @Test("A subscriber mid onboarding resumes at their step")
    func testASubscriberMidOnboardingResumesAtTheirStep() async {
        let screen = makeScreen()
        screen.interactor.isPremium = true
        screen.interactor.userAfterLogin = onboardingStageUser(upTo: .gymProfileSetup)

        screen.presenter.handleOnAuthSuccess(user: UserAuthInfo(uid: "user-1"), isNewUser: false)

        #expect(await TestManagers.eventually { !screen.router.shown.isEmpty })
        #expect(screen.router.shown == ["gymProfileSetup"])
    }

    /// Reinstalling on a new device restores the purchase but arrives as a "new" account to the
    /// auth layer. The stored profile is what decides, so this user is not made to redo anything.
    @Test("A restored subscriber with a finished profile reaches the app")
    func testARestoredSubscriberWithAFinishedProfileReachesTheApp() async {
        let screen = makeScreen()
        screen.interactor.isPremium = true
        screen.interactor.userAfterLogin = onboardingStageUser(upTo: .complete)

        screen.presenter.handleOnAuthSuccess(user: UserAuthInfo(uid: "user-1"), isNewUser: true)

        #expect(await TestManagers.eventually { !screen.router.shown.isEmpty })
        #expect(screen.router.shown == ["coreModule"])
    }

    /// Logging in is the half that talks to Firestore, so it fails on its own — and when it does,
    /// the user is still standing on the sign-in screen and has to be told.
    @Test("A failed login is surfaced and routes nowhere")
    func testAFailedLoginIsSurfacedAndGoesNowhere() async {
        let screen = makeScreen()
        screen.interactor.logInError = URLError(.notConnectedToInternet)

        screen.presenter.handleOnAuthSuccess(user: UserAuthInfo(uid: "user-1"), isNewUser: true)

        #expect(await TestManagers.eventually { !screen.router.alertTitles.isEmpty })
        #expect(screen.router.alertTitles == ["Error Logging In"])
        #expect(screen.router.shown.isEmpty)
    }

    /// Login failing is the more serious of the two halves — the provider already said yes, so the
    /// user has an identity the app then failed to admit. That has to be visible in the numbers.
    @Test("A failed login is recorded as a failure")
    func testAFailedLoginIsRecordedAsAFailure() async {
        let screen = makeScreen()
        screen.interactor.logInError = URLError(.notConnectedToInternet)

        screen.presenter.handleOnAuthSuccess(user: UserAuthInfo(uid: "user-1"), isNewUser: true)

        #expect(await TestManagers.eventually { screen.interactor.trackedEventNames.contains("Auth_UserLogin_Fail") })
        #expect(!screen.interactor.trackedEventNames.contains("Auth_UserLogin_Success"))
    }

    /// The worst shape of all: login *succeeded* and the profile still was not there, so the
    /// presenter returned and the user sat on the sign-in screen behind a Success event with no
    /// destination and no alert. The profile arrives when the sync engine's listener next emits,
    /// so this is a race rather than a theoretical branch — it has to be visible in the numbers.
    @Test("A login that succeeds without a profile is recorded rather than swallowed")
    func testALoginWithoutAProfileIsRecorded() async {
        let screen = makeScreen()
        screen.interactor.isPremium = true
        screen.interactor.userAfterLogin = nil

        screen.presenter.handleOnAuthSuccess(user: UserAuthInfo(uid: "user-1"), isNewUser: false)

        #expect(await TestManagers.eventually {
            screen.interactor.trackedEventNames.contains("Auth_UserLogin_NoCurrentUser")
        })
        #expect(screen.router.shown.isEmpty)
    }

    // MARK: - Leaving the screen

    /// The screen is left behind the moment auth succeeds, and `cleanUp` runs on the way out. It
    /// must not leave a cancelled task behind for a later attempt to trip over.
    @Test("Leaving the screen clears the in-flight attempt")
    func testLeavingTheScreenClearsTheInFlightAttempt() {
        let screen = makeScreen()
        screen.interactor.userAfterLogin = onboardingStageUser(upTo: .completeAccountSetup)

        screen.presenter.onSignInApplePressed()
        #expect(screen.presenter.currentAuthTask != nil)

        screen.presenter.cleanUp()

        #expect(screen.presenter.currentAuthTask == nil)
    }

    /// The gym and training-mesocycle steps hand `handleNavigation` back as their completion
    /// callback, so it is called again after the user has moved on and must cope with there being
    /// nobody signed in.
    @Test("Re-navigating without a signed-in user does nothing")
    func testReNavigatingWithoutAUserDoesNothing() {
        let screen = makeScreen()

        screen.presenter.handleNavigation()

        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.trackedEventNames.isEmpty)
    }
}
