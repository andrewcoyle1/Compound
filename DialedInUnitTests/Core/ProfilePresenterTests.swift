//
//  ProfilePresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The Profile screen, which is the app's settings root: every per-area settings screen is reached
/// from one of its rows, and a row that goes nowhere is a setting the user simply cannot change.
///
/// So the tests here are about reachability rather than presentation — each row is asserted to open
/// the screen it names, because the alternative failure is silent.
@MainActor
struct ProfilePresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, ProfileInteractor {
        var currentUser: UserModel?
        var currentGoal: WeightGoal?
        var currentDietPlan: DietPlan?
        var isPremium: Bool = false
        var invite = InviteModel(code: "PUSH2345", inviterId: "me")
        var inviteFails = false
        func myInvite() async throws -> InviteModel {
            if inviteFails { throw InviteError.unavailable }
            return invite
        }
    }

    private final class Router: ProfileRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        func showAccountView(delegate: AccountDelegate) { shown.append("account") }
        func showNotificationsView() { shown.append("notifications") }
        func showExercisesView() { shown.append("exercises") }
        func showWorkoutSettingsView(delegate: WorkoutSettingsDelegate) { shown.append("workoutSettings") }
        func showGymProfilesView() { shown.append("gymProfiles") }
        func showTutorialsView(delegate: TutorialsDelegate) { shown.append("tutorials") }
        func showAboutView(delegate: AboutDelegate) { shown.append("about") }
        func showAppIconView(delegate: AppIconDelegate) { shown.append("appIcon") }
        func showUnitsView(delegate: UnitsDelegate) { shown.append("units") }
        func showIntegrationsView(delegate: IntegrationsDelegate) { shown.append("integrations") }
        func showSiriView(delegate: SiriDelegate) { shown.append("siri") }
        func showLegalView(delegate: LegalDelegate) { shown.append("legal") }
        func showPaywall() { shown.append("paywall") }
        func showShortcutsView(delegate: ShortcutsDelegate) { shown.append("shortcuts") }
        func showCustomiseAnalyticsView(delegate: CustomiseAnalyticsDelegate) { shown.append("customiseAnalytics") }
        func showFoodLogSettingsView(delegate: FoodLogSettingsDelegate) { shown.append("foodLogSettings") }
        func showExpenditureSettingsView(delegate: ExpenditureSettingsDelegate) { shown.append("expenditureSettings") }
        func showStrategySettingsView(delegate: StrategySettingsDelegate) { shown.append("strategySettings") }
        func showPreferredDietView(isFromSettings: Bool) { shown.append("preferredDiet-\(isFromSettings)") }
        func showShareSheet(items: [Any]) { shown.append("share: \(items.first as? String ?? "")") }
        func showSimpleAlert(title: String, subtitle: String?) { shown.append("alert: \(title)") }
        private(set) var ratingsYesPressed: (() -> Void)?
        private(set) var ratingsNoPressed: (() -> Void)?

        func showRatingsModal(onYesPressed: @escaping () -> Void, onNoPressed: @escaping () -> Void) {
            shown.append("ratings")
            ratingsYesPressed = onYesPressed
            ratingsNoPressed = onNoPressed
        }
    }

    private struct Screen {
        let presenter: ProfilePresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(user: UserModel? = UserModel(userId: "user-1")) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = user
        let router = Router()
        return Screen(
            presenter: ProfilePresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - Subscription

    /// Subscription management has to be reachable: the App Store expects a way to it from inside
    /// the app, and a subscriber who cannot find one cancels through Settings instead.
    @Test("Test The Subscription Row Opens The Paywall")
    func testTheSubscriptionRowOpensThePaywall() {
        let screen = makeScreen()

        screen.presenter.onSubscriptionPressed()

        #expect(screen.router.shown == ["paywall"])
        #expect(screen.interactor.trackedEventNames == ["ProfileView_Subscription_Press"])
    }

    /// The status told every user they were FREE, because the only screen that showed it read a
    /// stored property nothing assigned. It follows the entitlement now.
    @Test("Test The Subscription Status Follows The Entitlement")
    func testTheSubscriptionStatusFollowsTheEntitlement() {
        let screen = makeScreen()

        screen.interactor.isPremium = false
        #expect(screen.presenter.subscriptionStatus == "FREE")

        screen.interactor.isPremium = true
        #expect(screen.presenter.subscriptionStatus == "PREMIUM")
    }

    // MARK: - Nutrition Plan

    /// The diet flow is the only way to change calories and macros once onboarding is over, and the
    /// row that opened it lived on a screen nothing navigated to. It has to be entered with
    /// `isFromSettings` true: false sends the user on to the Strava step of onboarding after saving.
    @Test("Test The Nutrition Plan Row Opens The Diet Flow In Settings Mode")
    func testTheNutritionPlanRowOpensTheDietFlowInSettingsMode() {
        let screen = makeScreen()

        screen.presenter.onNutritionPlanPressed()

        #expect(screen.router.shown == ["preferredDiet-true"])
        #expect(screen.interactor.trackedEventNames == ["ProfileView_NutritionPlan_Press"])
    }

    // MARK: - The rest of the rows

    @Test("Test Every Nutrition Settings Row Opens Its Screen")
    func testEveryNutritionSettingsRowOpensItsScreen() {
        let screen = makeScreen()

        screen.presenter.onFoodLogSettingsPressed()
        screen.presenter.onExpenditureSettingsPressed()
        screen.presenter.onStrategySettingsPressed()
        screen.presenter.onNutritionPlanPressed()

        #expect(screen.router.shown == [
            "foodLogSettings",
            "expenditureSettings",
            "strategySettings",
            "preferredDiet-true"
        ])
    }

    @Test("Test Every Training Settings Row Opens Its Screen")
    func testEveryTrainingSettingsRowOpensItsScreen() {
        let screen = makeScreen()

        screen.presenter.onGymProfilesPressed()
        screen.presenter.onExerciseLibraryPressed()
        screen.presenter.onWorkoutSettingsPressed()

        #expect(screen.router.shown == ["gymProfiles", "exercises", "workoutSettings"])
    }

    // MARK: - Ratings

    /// These were logged as `SettingsView_*` from a screen called Profile, and the SettingsView they
    /// were named after has since been deleted — so the prompt's funnel was filed under a screen
    /// that no longer exists.
    @Test("Test The Ratings Prompt Is Tracked Under The Screen It Is Shown From")
    func testTheRatingsPromptIsTrackedUnderTheScreenItIsShownFrom() {
        let screen = makeScreen()

        screen.presenter.onRatingsButtonPressed()
        screen.router.ratingsNoPressed?()

        #expect(screen.router.shown == ["ratings"])
        #expect(screen.interactor.trackedEventNames == [
            "ProfileView_Ratings_Pressed",
            "ProfileView_RatingsNo_Pressed"
        ])
    }

    /// The "yes" branch hands off to StoreKit, which has no window to present from in a test, so its
    /// name is asserted on the event rather than by driving the button.
    @Test("Test The Ratings Yes Event Is Named For The Profile Screen")
    func testTheRatingsYesEventIsNamedForTheProfileScreen() {
        #expect(ProfilePresenter.Event.ratingsYesPressed.eventName == "ProfileView_RatingsYes_Pressed")
    }

    // MARK: - Invites

    /// The row shares the user's own link in the message a friend receives.
    @Test("Test Invite A Friend Shares The Invite Link")
    func testInviteAFriendSharesTheInviteLink() async {
        let screen = makeScreen()

        await screen.presenter.onInviteFriendPressed()

        #expect(screen.router.shown == ["share: Train with me on Compound: compound://join/PUSH2345"])
        #expect(screen.interactor.trackedEventNames == ["ProfileView_InviteFriend_Press"])
    }

    /// Creating the invite is a server write the first time, so offline it is not started.
    @Test("Test Offline Invite Says You're Offline Instead Of Sharing")
    func testOfflineInviteSaysYoureOfflineInsteadOfSharing() async {
        let screen = makeScreen()
        screen.interactor.isOffline = true

        await screen.presenter.onInviteFriendPressed()

        #expect(screen.router.shown == ["alert: \(OfflineError.title)"])
    }

    /// No invite, no share sheet with nothing in it.
    @Test("Test A Failed Invite Says So Instead Of Sharing")
    func testAFailedInviteSaysSoInsteadOfSharing() async {
        let screen = makeScreen()
        screen.interactor.inviteFails = true

        await screen.presenter.onInviteFriendPressed()

        #expect(screen.router.shown == ["alert: Couldn't create invite"])
    }
}
