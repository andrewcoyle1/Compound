//
//  SettingsPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The Settings screen, pushed from the profile's gear: the app's settings root: every per-area settings screen is reached
/// from one of its rows, and a row that goes nowhere is a setting the user simply cannot change.
///
/// So the tests here are about reachability rather than presentation — each row is asserted to open
/// the screen it names, because the alternative failure is silent.
@MainActor
struct SettingsPresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, SettingsInteractor {
        var currentUser: UserModel?
        var auth: UserAuthInfo?
        private(set) var didSignOut = false
        var signOutError: Error?
        func signOut() async throws {
            if let signOutError { throw signOutError }
            didSignOut = true
        }
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

    private final class Router: SettingsRouter {
        private(set) var coachChatsShown = 0
        func showCoachChatsView(delegate: CoachChatsDelegate) { coachChatsShown += 1 }
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        func showWeightGoalFlow() { shown.append("weightGoal") }
        func switchToOnboardingModule() { shown.append("onboarding") }
        func showAuthView() { shown.append("auth") }
        func showDeleteAccountView() { shown.append("deleteAccount") }
        func showNotificationsView() { shown.append("notifications") }
        func showNotificationSettingsView(delegate: NotificationSettingsDelegate) { shown.append("notificationSettings") }
        func showWorkoutSettingsView(delegate: WorkoutSettingsDelegate) { shown.append("workoutSettings") }
        func showGymProfilesView() { shown.append("gymProfiles") }
        func showTutorialsView(delegate: TutorialsDelegate) { shown.append("tutorials") }
        func showAboutView(delegate: AboutDelegate) { shown.append("about") }
        func showAppIconView(delegate: AppIconDelegate) { shown.append("appIcon") }
        func showUnitsView(delegate: UnitsDelegate) { shown.append("units") }
        func showIntegrationsView(delegate: IntegrationsDelegate) { shown.append("integrations") }
        func showSiriView(delegate: SiriDelegate) { shown.append("siri") }
        func showLegalView(delegate: LegalDelegate) { shown.append("legal") }
        func showPaywall(isOnboarding: Bool) { shown.append("paywall") }
        func showCustomiseAnalyticsView(delegate: CustomiseAnalyticsDelegate) { shown.append("customiseAnalytics") }
        func showFoodLogSettingsView(delegate: FoodLogSettingsDelegate) { shown.append("foodLogSettings") }
        func showExpenditureSettingsView(delegate: ExpenditureSettingsDelegate) { shown.append("expenditureSettings") }
        func showStrategySettingsView(delegate: StrategySettingsDelegate) { shown.append("strategySettings") }
        func showPreferredDietView(isFromSettings: Bool) { shown.append("preferredDiet-\(isFromSettings)") }
        func showShareSheet(items: [Any]) { shown.append("share: \(items.first as? String ?? "")") }
        func showSimpleAlert(title: String, subtitle: String?) { shown.append("alert: \(title)") }
    }

    private struct Screen {
        let presenter: SettingsPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(user: UserModel? = UserModel(userId: "user-1"), isAnonymous: Bool = false) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = user
        interactor.auth = UserAuthInfo(uid: user?.userId ?? "user-1", isAnonymous: isAnonymous)
        let router = Router()
        return Screen(
            presenter: SettingsPresenter(interactor: interactor, router: router),
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
        #expect(!screen.presenter.isManageSubscriptionsPresented)
        #expect(screen.interactor.trackedEventNames == ["ProfileView_Subscription_Press"])
    }

    /// A subscriber was shown the paywall, which made an active subscription look lapsed and
    /// offered no way to cancel. They get Apple's Manage Subscriptions sheet instead.
    @Test("Test A Subscriber Manages Their Subscription Instead Of Seeing The Paywall")
    func testASubscriberManagesTheirSubscriptionInsteadOfSeeingThePaywall() {
        let screen = makeScreen()
        screen.interactor.isPremium = true

        screen.presenter.onSubscriptionPressed()

        #expect(screen.router.shown.isEmpty)
        #expect(screen.presenter.isManageSubscriptionsPresented)
    }

    /// The status told every user they were FREE, because the only screen that showed it read a
    /// stored property nothing assigned. It follows the entitlement now.
    @Test("Test The Subscription Status Follows The Entitlement")
    func testTheSubscriptionStatusFollowsTheEntitlement() {
        let screen = makeScreen()

        // Was "Free" and "Premium", tier names for a product that has one name (Compound) and
        // no free version.
        screen.interactor.isPremium = false
        #expect(screen.presenter.subscriptionStatus == "Inactive")

        screen.interactor.isPremium = true
        #expect(screen.presenter.subscriptionStatus == "Active")
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
        screen.presenter.onWorkoutSettingsPressed()

        #expect(screen.router.shown == ["gymProfiles", "workoutSettings"])
    }

    /// Notification Settings was reachable only from the gear on Notifications.
    @Test("Test The Notification Settings Row Opens Notification Settings")
    func testTheNotificationSettingsRowOpensNotificationSettings() {
        let screen = makeScreen()

        screen.presenter.onNotificationSettingsPressed()

        #expect(screen.router.shown == ["notificationSettings"])
        #expect(screen.interactor.trackedEventNames == ["ProfileView_NotificationSettings_Press"])
    }

    // MARK: - Ratings

    /// The row goes straight to the system prompt. It used to open a sentiment modal naming
    /// another app ("Are you enjoying AIChat?") first.
    @Test("Test The Ratings Row Opens No Modal Of Its Own")
    func testTheRatingsRowOpensNoModalOfItsOwn() {
        #expect(SettingsPresenter.Event.ratingsPressed.eventName == "ProfileView_Ratings_Pressed")
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

    // MARK: - Security

    @Test("Test Settings Says How The Person Signs In")
    func testSettingsSaysHowThePersonSignsIn() {
        let apple = makeScreen()
        apple.interactor.auth = UserAuthInfo(uid: "user-1", isAnonymous: false, authProviders: [.apple])
        #expect(apple.presenter.signInMethod == "Apple")

        let google = makeScreen()
        google.interactor.auth = UserAuthInfo(uid: "user-1", isAnonymous: false, authProviders: [.google])
        #expect(google.presenter.signInMethod == "Google")

        #expect(makeScreen(isAnonymous: true).presenter.signInMethod == "Not saved")
    }

    // MARK: - Upgrading an anonymous account

    /// Signing an anonymous account out is irreversible — there is no credential to sign back in
    /// with — so that account is offered the upgrade in place of Log Out. This was the only screen
    /// in the app offering it, and it was on a screen nothing navigated to.
    @Test("Test An Anonymous Account Is Offered The Upgrade Instead Of Log Out")
    func testAnAnonymousAccountIsOfferedTheUpgradeInsteadOfLogOut() {
        #expect(makeScreen(isAnonymous: true).presenter.isAnonymousUser)
        #expect(!makeScreen(isAnonymous: false).presenter.isAnonymousUser)
    }

    /// The upgrade goes to the same `AuthView` onboarding uses, which links a credential to the
    /// signed-in anonymous user rather than replacing it, so the data logged so far survives.
    @Test("Test Saving An Anonymous Account Opens Sign In")
    func testSavingAnAnonymousAccountOpensSignIn() {
        let screen = makeScreen(isAnonymous: true)

        screen.presenter.onSaveAccountPressed()

        #expect(screen.router.shown == ["auth"])
        #expect(!screen.interactor.didSignOut)
        #expect(screen.interactor.trackedEventNames == ["Settings_SaveAccount_Press"])
    }

    // MARK: - Sign out

    /// Signing out has to actually sign out and then put the user back on the onboarding module.
    /// Leaving them on a settings screen belonging to an account they no longer hold is the
    /// half-state this guards against.
    @Test("Test Signing Out Signs Out And Returns To Onboarding")
    func testSigningOutSignsOutAndReturnsToOnboarding() async {
        let screen = makeScreen()

        screen.presenter.onSignOutPressed()

        await TestManagers.eventually { screen.router.shown.contains("onboarding") }
        #expect(screen.interactor.didSignOut)
        #expect(screen.interactor.trackedEventNames.contains("Settings_SignOut_Success"))
    }

    /// A sign-out that fails leaves the user signed in. Switching to onboarding anyway would show
    /// the welcome flow to someone whose session is still live, and the next screen they reach
    /// would be full of their data again.
    @Test("Test A Failed Sign Out Leaves The User Signed In")
    func testAFailedSignOutLeavesTheUserSignedIn() async {
        let screen = makeScreen()
        screen.interactor.signOutError = URLError(.networkConnectionLost)

        screen.presenter.onSignOutPressed()

        await TestManagers.eventually { screen.interactor.trackedEventNames.contains("Settings_SignOut_Fail") }
        #expect(!screen.router.shown.contains("onboarding"))
        #expect(!screen.interactor.didSignOut)
        #expect(!screen.interactor.trackedEventNames.contains("Settings_SignOut_Success"))
    }

    // MARK: - Delete account

    /// Delete Account opens the confirmation screen and deletes nothing. It used to raise an alert
    /// that said nothing about the subscription, the sign-in or the timing; the deletion itself is
    /// now `DeleteAccountPresenterTests`.
    @Test("Test Pressing Delete Account Opens The Confirmation And Destroys Nothing")
    func testPressingDeleteAccountOpensTheConfirmationAndDestroysNothing() {
        let screen = makeScreen()

        screen.presenter.onDeleteAccountPressed()

        #expect(screen.router.shown == ["deleteAccount"])
                #expect(screen.interactor.trackedEventNames == ["Settings_DeleteAccount_Start"])
    }
}
