//
//  OnboardingEntryPresenterTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The way into the app: the splash and the subscription pitch.
///
/// Onboarding runs once. Anyone who has finished it never sees these screens again, so a user
/// sent to the wrong place here is stranded somewhere nobody with the app installed will look.

/// Builds a user standing at a chosen point of onboarding, by filling in exactly the fields
/// `inferredOnboardingStep` reads before that point.
///
/// A fixed date of birth keeps the model stable between two reads of it — the shipped
/// `UserModel.mock` is computed from `Date()` and is not.
@MainActor
func onboardingStageUser(
    upTo step: OnboardingStep,
    userId: String = "user-1",
    isAnonymous: Bool? = false,
    weightKilograms: Double? = 80
) -> UserModel {
    let dateOfBirth = Calendar.current.date(from: DateComponents(year: 1990, month: 4, day: 12))
    // The order `inferredOnboardingStep` checks its fields in. Gym profile really does come before
    // the training mesocycle there, even though `OnboardingStep.orderIndex` lists them the other way.
    let order: [OnboardingStep] = [
        .completeAccountSetup, .healthDisclaimer, .goalSetting,
        .gymProfileSetup, .mesocycleSetup, .customiseProgram, .complete
    ]
    // Every step strictly before `step` has been answered; `step` itself has not, so the fields
    // that step fills in are the first ones left empty.
    func answered(_ other: OnboardingStep) -> Bool {
        guard let target = order.firstIndex(of: step), let candidate = order.firstIndex(of: other) else {
            return false
        }
        return candidate < target
    }

    let setupDone = answered(.completeAccountSetup)
    return UserModel(
        userId: userId,
        isAnonymous: isAnonymous,
        submittedDateOfBirth: setupDone ? dateOfBirth : nil,
        submittedGender: setupDone ? .male : nil,
        submittedHeightCentimeters: setupDone ? 180 : nil,
        submittedWeightKilograms: setupDone ? weightKilograms : nil,
        submittedExerciseFrequency: setupDone ? .threeToFour : nil,
        submittedDailyActivityLevel: setupDone ? .moderate : nil,
        submittedCardioFitnessLevel: setupDone ? .intermediate : nil,
        submittedCurrentGoalId: answered(.goalSetting) ? "goal-1" : nil,
        submittedActiveMesocycleId: answered(.mesocycleSetup) ? "program-1" : nil,
        submittedFavouriteGymProfileId: answered(.gymProfileSetup) ? "gym-1" : nil,
        didCompleteOnboarding: step == .complete,
        acceptedHealthDisclaimerVersion: answered(.healthDisclaimer) ? UserModel.currentHealthDisclaimerVersion : nil
    )
}

// MARK: - The splash screen

/// The first thing anyone sees, and the only screen that has to tell four kinds of visitor apart:
/// somebody who has never signed in, somebody signed in anonymously, somebody part-way through
/// onboarding, and somebody returning to an account that is already finished.
@MainActor
struct OnboardingWelcomePresenterTests {

    private final class Interactor: SpyGlobalInteractor, WelcomeInteractor {
        var currentUser: UserModel?
        var isPremium: Bool

        init(currentUser: UserModel? = nil, isPremium: Bool = false) {
            self.currentUser = currentUser
            self.isPremium = isPremium
        }
    }

    /// Welcome can reach the shared onboarding steps as well as its own five destinations, so the
    /// shared spy is subclassed rather than replaced.
    private final class Router: SpyOnboardingRouter, WelcomeRouter {
        // The test target builds without `-DDEV`, but the app module it imports does not, so the
        // requirement is present and has to be satisfied unguarded.
        func showDevSettingsView() { record("devSettings") }
        func showPaywall(isOnboarding: Bool) { record("paywall(onboarding: \(isOnboarding))") }
        func showAuthView() { record("auth") }
        func showSubscriptionView() { record("subscription") }
        func switchToCoreModule() { record("coreModule") }
    }

    private struct Screen {
        let presenter: WelcomePresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(user: UserModel? = nil, isPremium: Bool = false) -> Screen {
        let interactor = Interactor(currentUser: user, isPremium: isPremium)
        let router = Router()
        return Screen(
            presenter: WelcomePresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// Nobody signed in: Get Started goes straight to sign-in. The "Why Compound?" pitch that sat
    /// between them is gone.
    @Test("A visitor with no account goes straight to sign in")
    func testAVisitorWithNoAccountGoesStraightToSignIn() {
        let screen = makeScreen(user: nil)

        screen.presenter.onContinuePressed()

        #expect(screen.router.shown == ["auth"])
    }

    /// An anonymous account is not an account yet — sending one of these on into onboarding would
    /// collect a profile that is lost the moment the device is.
    @Test("An anonymous user is sent to sign in rather than resuming onboarding")
    func testAnAnonymousUserIsSentToSignIn() {
        let screen = makeScreen(user: onboardingStageUser(upTo: .goalSetting, isAnonymous: true))

        screen.presenter.onContinuePressed()

        #expect(screen.router.shown == ["auth"])
    }

    /// `isAnonymous` is optional on the model, and an unset flag means the document predates the
    /// field rather than that it is a full account. Treating nil as "not anonymous" would push
    /// someone with no credentials into the signed-in flow.
    @Test("An unset anonymous flag is treated as anonymous")
    func testAnUnsetAnonymousFlagIsTreatedAsAnonymous() {
        let screen = makeScreen(user: onboardingStageUser(upTo: .goalSetting, isAnonymous: nil))

        screen.presenter.onContinuePressed()

        #expect(screen.router.shown == ["auth"])
    }

    /// A returning subscriber should never see onboarding again.
    @Test("A finished subscriber goes straight to the app")
    func testAFinishedSubscriberGoesStraightToTheApp() {
        let screen = makeScreen(user: onboardingStageUser(upTo: .complete), isPremium: true)

        screen.presenter.onContinuePressed()

        #expect(screen.router.shown == ["coreModule"])
    }

    /// Finished onboarding but no subscription (a lapsed subscriber): the app is gated, so "Why
    /// Subscribe?" is next, as after signing in. It used to go straight to the paywall, skipping the
    /// screen that says a subscription is required and offers Sign Out and Account.
    @Test("A finished user without a subscription sees Why Subscribe")
    func testAFinishedUserWithoutASubscriptionSeesThePaywall() {
        let screen = makeScreen(user: onboardingStageUser(upTo: .complete), isPremium: false)

        screen.presenter.onContinuePressed()

        #expect(screen.router.shown == ["subscription"])
    }

    /// Someone who quit half way through is put back where they stopped, not at the start.
    @Test("An interrupted user resumes where they stopped")
    func testAnInterruptedUserResumesWhereTheyStopped() {
        let screen = makeScreen(user: onboardingStageUser(upTo: .goalSetting))

        screen.presenter.onContinuePressed()

        #expect(screen.router.shown == ["objective"])
    }

    /// A signed-in user with nothing filled in resumes at the profile questions rather than at
    /// auth or the subscription pitch, both of which they are already past.
    @Test("A signed-in user with an empty profile resumes at account setup")
    func testASignedInUserWithAnEmptyProfileResumesAtAccountSetup() {
        let screen = makeScreen(user: onboardingStageUser(upTo: .completeAccountSetup))

        screen.presenter.onContinuePressed()

        #expect(screen.router.shown == ["namePhoto"])
    }

    /// The gym step is reached through a delegate rather than a plain push, which makes it the one
    /// destination the shared switch has to build an argument for.
    @Test("A user who has not set up a gym resumes at the gym profile step")
    func testAUserWithoutAGymResumesAtTheGymProfileStep() {
        let screen = makeScreen(user: onboardingStageUser(upTo: .gymProfileSetup))

        screen.presenter.onContinuePressed()

        #expect(screen.router.shown == ["gymProfileSetup"])
    }

    /// Everything answered but Finish never pressed: the diet screens are the last step, and this
    /// user goes back to them rather than being counted as done.
    @Test("A user who never pressed finish returns to the last step")
    func testAUserWhoNeverPressedFinishReturnsToTheLastStep() {
        let screen = makeScreen(user: onboardingStageUser(upTo: .customiseProgram))

        screen.presenter.onContinuePressed()

        #expect(screen.router.shown == ["customisingDietProgram"])
    }

    /// `handleNavigation` is the callback the gym and mesocycle steps fire when they finish, so it
    /// has to be safe to call when the session has gone away underneath it.
    @Test("Re-navigating without a signed-in user does nothing")
    func testReNavigatingWithoutAUserDoesNothing() {
        let screen = makeScreen(user: nil)

        screen.presenter.handleNavigation()

        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.trackedEventNames.isEmpty)
    }

    /// The gym and mesocycle steps call back into this, so it routes on the profile as it stands
    /// *now* — after the step that just finished wrote to it.
    @Test("Re-navigating routes on the profile as it now stands")
    func testReNavigatingRoutesOnTheProfileAsItNowStands() {
        let screen = makeScreen(user: onboardingStageUser(upTo: .gymProfileSetup))

        screen.presenter.handleNavigation()
        // The gym step has finished and written its id, so the next call must move on rather than
        // sending the user back to the gym screen a second time.
        screen.interactor.currentUser = onboardingStageUser(upTo: .mesocycleSetup)
        screen.presenter.handleNavigation()

        #expect(screen.router.shown == ["gymProfileSetup", "trainingProgramSetup"])
    }

    @Test("Appearing and disappearing are tracked separately")
    func testAppearingAndDisappearingAreTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: WelcomeDelegate())
        screen.presenter.onViewDisappear(delegate: WelcomeDelegate())

        #expect(screen.interactor.trackedScreenEventNames == ["WelcomeView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["WelcomeView_Disappear"])
    }
}

// MARK: - The subscription pitch

/// The screen that explains the subscription before the paywall itself is shown.
@MainActor
struct OnboardingSubscriptionPresenterTests {

    private final class Interactor: SpyGlobalInteractor, SubscriptionInteractor {
        var signOutError: Error?
        private(set) var didSignOut = false
        func signOut() async throws {
            if let signOutError { throw signOutError }
            didSignOut = true
        }
    }

    private final class Router: SubscriptionRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var paywallsShown: [Bool] = []
        private(set) var shown: [String] = []

        func showDevSettingsView() { shown.append("devSettings") }
        func showPaywall(isOnboarding: Bool) { paywallsShown.append(isOnboarding) }
        func showEditProfileView(delegate: EditProfileDelegate) { shown.append("account") }
        func switchToOnboardingModule() { shown.append("onboardingModule") }

        private(set) var alertTitles: [String] = []
        func showAlert(title: String, error: Error) { alertTitles.append(title) }
    }

    /// The paywall behaves differently inside onboarding — dismissing it has to continue the flow
    /// rather than drop the user into an app they have not set up.
    @Test("Continuing opens the paywall as part of onboarding")
    func testThePaywallIsOpenedAsPartOfOnboarding() {
        let interactor = Interactor()
        let router = Router()
        let presenter = SubscriptionPresenter(interactor: interactor, router: router)

        presenter.onContinuePressed()

        #expect(router.paywallsShown == [true])
        // The screen pitches the subscription; it must not skip past the paywall into setup.
        #expect(router.shown.isEmpty)
        #expect(interactor.trackedEventNames == ["SubscriptionInfoView_Navigate"])
    }

    /// Continue is the only control on the screen. The presenter keeps no "already pressed" state,
    /// so a second press has to be honoured rather than swallowed.
    @Test("Each press of continue opens the paywall again")
    func testEachPressOpensThePaywallAgain() {
        let router = Router()
        let presenter = SubscriptionPresenter(interactor: Interactor(), router: router)

        presenter.onContinuePressed()
        presenter.onContinuePressed()

        #expect(router.paywallsShown == [true, true])
    }

    /// Someone who will not subscribe can open their account, which reaches Delete Account,
    /// without paying.
    @Test("The account row opens the account")
    func testTheAccountRowOpensTheAccount() {
        let interactor = Interactor()
        let router = Router()
        let presenter = SubscriptionPresenter(interactor: interactor, router: router)

        presenter.onAccountPressed()

        #expect(router.shown == ["account"])
        #expect(interactor.trackedEventNames == ["SubscriptionInfoView_Account_Press"])
    }

    @Test("Signing out returns to the start of onboarding")
    func testSigningOutReturnsToTheStartOfOnboarding() async {
        let interactor = Interactor()
        let router = Router()
        let presenter = SubscriptionPresenter(interactor: interactor, router: router)

        presenter.onSignOutPressed()

        #expect(await TestManagers.eventually { router.shown == ["onboardingModule"] })
        #expect(interactor.didSignOut)
    }

    /// A failed sign-out leaves the person signed in, here, and says so.
    @Test("A failed sign out stays put and says so")
    func testAFailedSignOutStaysPutAndSaysSo() async {
        let interactor = Interactor()
        interactor.signOutError = URLError(.notConnectedToInternet)
        let router = Router()
        let presenter = SubscriptionPresenter(interactor: interactor, router: router)

        presenter.onSignOutPressed()

        #expect(await TestManagers.eventually { !router.alertTitles.isEmpty })
        #expect(router.alertTitles == ["Unable to Sign Out"])
        #expect(router.shown.isEmpty)
    }
}
