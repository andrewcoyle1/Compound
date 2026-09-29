//
//  AppShellPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

enum AppShellTestError: Error { case failed }

// MARK: - App root

/// The screen behind every other screen: what the app shows when it is opened, and how it gets a
/// user to show it to.
///
/// Two things here are worth more than the rest. The first is `activeModuleId`, which is the whole
/// launch decision — onboarding or the tab bar — and must be whatever the app state says rather
/// than anything the presenter works out for itself; a presenter that second-guessed it would send
/// a finished user back through onboarding. The second is `checkUserStatus`, which must never
/// leave the app with no user at all: every failure path retries rather than giving up, because
/// there is no screen to show someone who is not signed in.
///
/// `checkUserStatus`'s anonymous-success branch asks Firebase Messaging for a token, and
/// `Messaging.messaging()` traps when Firebase has not been configured — which it has not, in a
/// unit-test process. So the anonymous path is driven only as far as its failure and recovery.
@MainActor
struct AppShellAppPresenterTests {

    private final class Interactor: SpyGlobalInteractor, AppInteractor {
        var auth: UserAuthInfo?
        var startingModuleId: String = Constants.onboardingModuleId

        /// Errors are consumed one per call, so a test can say "fails once, then works" — which is
        /// what the retry loop is for.
        var logInErrors: [Error?] = []
        var signInErrors: [Error?] = []
        var saveTokenError: Error?

        /// Called after a failed anonymous sign-in, so the retry can be steered somewhere that does
        /// not reach Firebase Messaging.
        var onSignInFailure: (() -> Void)?

        private(set) var loggedInUids: [String] = []
        private(set) var signInAttempts = 0
        private(set) var savedTokens: [String] = []
        private(set) var didSchedulePushNotifications = false

        func logIn(user: UserAuthInfo, isNewUser: Bool) async throws {
            if !logInErrors.isEmpty, let error = logInErrors.removeFirst() { throw error }
            loggedInUids.append(user.uid)
        }

        func signInAnonymously() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
            signInAttempts += 1
            if !signInErrors.isEmpty, let error = signInErrors.removeFirst() {
                onSignInFailure?()
                throw error
            }
            return (UserAuthInfo(uid: "anon-1", isAnonymous: true), true)
        }

        func saveUserFCMToken(token: String) async throws {
            if let saveTokenError { throw saveTokenError }
            savedTokens.append(token)
        }

        func schedulePushNotificationsForNextWeek() { didSchedulePushNotifications = true }

        func syncAllRemoteDataIfLoggedIn() async { }
    }

    private struct Screen {
        let presenter: AppPresenter
        let interactor: Interactor
    }

    private func makeScreen(
        auth: UserAuthInfo? = nil,
        startingModuleId: String = Constants.onboardingModuleId
    ) -> Screen {
        let interactor = Interactor()
        interactor.auth = auth
        interactor.startingModuleId = startingModuleId
        return Screen(presenter: AppPresenter(interactor: interactor), interactor: interactor)
    }

    private func notification(_ model: ActivityNotificationModel) -> Notification {
        Notification(name: .newActivityNotification, object: model, userInfo: nil)
    }

    private func activity(id: String) -> ActivityNotificationModel {
        ActivityNotificationModel(
            id: id,
            type: .like,
            actorId: "actor-1",
            actorName: "Jane",
            actorImageUrl: nil,
            sessionId: "session-1",
            sessionAuthorId: "user-1",
            commentText: nil,
            dateCreated: Date(timeIntervalSince1970: 0),
            isRead: false
        )
    }

    // MARK: - What the app opens on

    /// A user who finished onboarding opens on the tab bar. The decision is made once, when the
    /// dependency graph is built, and the presenter's only job is not to alter it.
    @Test("Test A Finished User Opens On The Tab Bar")
    func testAFinishedUserOpensOnTheTabBar() {
        let screen = makeScreen(startingModuleId: Constants.tabBarModuleId)

        #expect(screen.presenter.activeModuleId == Constants.tabBarModuleId)
    }

    /// The mirror image: someone who has not finished opens on onboarding, not on a tab bar with
    /// no profile behind it.
    @Test("Test An Unfinished User Opens On Onboarding")
    func testAnUnfinishedUserOpensOnOnboarding() {
        let screen = makeScreen(startingModuleId: Constants.onboardingModuleId)

        #expect(screen.presenter.activeModuleId == Constants.onboardingModuleId)
    }

    /// The signed-out case, which is what a fresh install looks like before `checkUserStatus` has
    /// run: no auth to read, and onboarding to show.
    @Test("Test A Signed Out App Has No Auth And Shows Onboarding")
    func testASignedOutAppHasNoAuthAndShowsOnboarding() {
        let screen = makeScreen(auth: nil, startingModuleId: Constants.onboardingModuleId)

        #expect(screen.presenter.auth == nil)
        #expect(screen.presenter.activeModuleId == Constants.onboardingModuleId)
    }

    // MARK: - Getting a user

    /// An already-authenticated user is logged straight back in rather than replaced by a fresh
    /// anonymous account — that would lose everything they had.
    @Test("Test An Existing User Is Logged Back In Not Replaced")
    func testAnExistingUserIsLoggedBackInNotReplaced() async {
        let screen = makeScreen(auth: UserAuthInfo(uid: "existing-1"))

        await screen.presenter.checkUserStatus()

        #expect(screen.interactor.loggedInUids == ["existing-1"])
        #expect(screen.interactor.signInAttempts == 0)
        #expect(screen.interactor.trackedEventNames.contains("AppView_ExistingAuth_Start"))
    }

    /// Every returning-user launch logged a Start, and only the failures logged a terminal event.
    /// The success rate of the commonest launch path was therefore unmeasurable.
    @Test("Test A Successful Existing Login Reports Success")
    func testASuccessfulExistingLoginReportsSuccess() async {
        let screen = makeScreen(auth: UserAuthInfo(uid: "existing-1"))

        await screen.presenter.checkUserStatus()

        #expect(screen.interactor.trackedEventNames.contains("AppView_ExistingAuth_Success"))
        #expect(!screen.interactor.trackedEventNames.contains("AppView_ExistingAuth_Fail"))
    }

    /// A user with no account is signed in anonymously, so the app always has someone to show
    /// something to. Only the attempt is asserted: the success path continues into Firebase
    /// Messaging, which is not configured in a test process.
    @Test("Test A User With No Account Is Signed In Anonymously")
    func testAUserWithNoAccountIsSignedInAnonymously() async {
        let screen = makeScreen(auth: nil)
        // Fail once so the presenter stops before reaching `Messaging.messaging()`, then steer the
        // retry down the existing-auth branch.
        screen.interactor.signInErrors = [AppShellTestError.failed]
        screen.interactor.onSignInFailure = { [weak interactor = screen.interactor] in
            interactor?.auth = UserAuthInfo(uid: "recovered-1", isAnonymous: true)
        }

        await screen.presenter.checkUserStatus()

        #expect(screen.interactor.signInAttempts == 1)
        #expect(screen.interactor.trackedEventNames.contains("AppView_AnonAuth_Start"))
        #expect(screen.interactor.trackedEventNames.contains("AppView_AnonAuth_Fail"))
        // The retry recovered rather than leaving the app with nobody signed in.
        #expect(screen.interactor.loggedInUids == ["recovered-1"])
    }

    /// A login that fails is retried rather than abandoned. An app that gave up here would sit on
    /// whatever it launched into with no user behind it, and every screen would read as empty.
    @Test("Test A Failed Login Is Retried Rather Than Abandoned")
    func testAFailedLoginIsRetriedRatherThanAbandoned() async {
        let screen = makeScreen(auth: UserAuthInfo(uid: "existing-1"))
        screen.interactor.logInErrors = [AppShellTestError.failed]

        await screen.presenter.checkUserStatus()

        #expect(screen.interactor.trackedEventNames.contains("AppView_ExistingAuth_Fail"))
        #expect(screen.interactor.loggedInUids == ["existing-1"])
    }

    // MARK: - Push token

    /// The token is what lets the backend reach this device at all, so a token arriving late still
    /// gets saved.
    @Test("Test A Token Arriving By Notification Is Saved")
    func testATokenArrivingByNotificationIsSaved() async {
        let screen = makeScreen()

        screen.presenter.onFCMTokenRecieved(
            notification: Notification(name: .fcmToken, object: nil, userInfo: ["token": "abc-123"])
        )

        #expect(await TestManagers.eventually { screen.interactor.savedTokens == ["abc-123"] })
        #expect(screen.interactor.trackedEventNames.contains("AppView_FCM_Success"))
    }

    /// A notification with nothing usable in it is reported rather than saved as an empty token —
    /// registering "" would quietly stop notifications reaching this device.
    @Test("Test A Notification With No Token Saves Nothing")
    func testANotificationWithNoTokenSavesNothing() async {
        let screen = makeScreen()

        screen.presenter.onFCMTokenRecieved(
            notification: Notification(name: .fcmToken, object: nil, userInfo: ["something": "else"])
        )

        #expect(screen.interactor.savedTokens.isEmpty)
        #expect(screen.interactor.trackedEventNames.contains("AppView_FCM_Fail"))
        #expect(!screen.interactor.trackedEventNames.contains("AppView_FCM_Start"))
    }

    /// A save that fails is logged as a failure rather than reported as a success — the difference
    /// is whether anyone finds out that a device stopped receiving notifications.
    @Test("Test A Token That Cannot Be Saved Is Reported")
    func testATokenThatCannotBeSavedIsReported() async {
        let screen = makeScreen()
        screen.interactor.saveTokenError = AppShellTestError.failed

        screen.presenter.onFCMTokenRecieved(
            notification: Notification(name: .fcmToken, object: nil, userInfo: ["token": "abc-123"])
        )

        #expect(await TestManagers.eventually {
            screen.interactor.trackedEventNames.contains("AppView_FCM_Fail")
        })
        #expect(screen.interactor.savedTokens.isEmpty)
    }

    // MARK: - Activity banner

    /// The banner is the only thing a like or a comment shows while the app is open.
    @Test("Test An Activity Notification Raises The Banner")
    func testAnActivityNotificationRaisesTheBanner() {
        let screen = makeScreen()

        screen.presenter.onNewActivityNotification(notification: notification(activity(id: "a")))

        #expect(screen.presenter.activityBanner?.id == "a")
    }

    /// Anything that is not an activity is ignored. `NotificationCenter` is shared, so the guard is
    /// the only thing stopping an unrelated post from blanking or corrupting the banner.
    @Test("Test An Unrelated Notification Leaves The Banner Alone")
    func testAnUnrelatedNotificationLeavesTheBannerAlone() {
        let screen = makeScreen()
        screen.presenter.onNewActivityNotification(notification: notification(activity(id: "a")))

        screen.presenter.onNewActivityNotification(
            notification: Notification(name: .newActivityNotification, object: "not an activity", userInfo: nil)
        )

        #expect(screen.presenter.activityBanner?.id == "a")
    }

    /// A second notification replaces the first immediately, and the banner clears itself
    /// afterwards. The auto-dismiss is keyed on the banner's id precisely so the first one's timer
    /// cannot pull the second one off the screen early.
    @Test("Test A Newer Banner Replaces The Older One Then Clears")
    func testANewerBannerReplacesTheOlderOneThenClears() async {
        let screen = makeScreen()

        screen.presenter.onNewActivityNotification(notification: notification(activity(id: "a")))
        screen.presenter.onNewActivityNotification(notification: notification(activity(id: "b")))
        #expect(screen.presenter.activityBanner?.id == "b")

        // Only the clearing is waited on. Both banners are created within microseconds of each
        // other, so "a"'s timer and "b"'s fire at effectively the same moment — there is no
        // instant at which "b" can be observed having outlived "a"'s timer and not yet its own.
        // What is left to prove is that the screen ends up empty, and the window is wide because
        // a loaded machine can delay a four-second timer well past six seconds. It cost a
        // false failure in a full run.
        #expect(await TestManagers.eventually(timeout: .seconds(20)) { screen.presenter.activityBanner == nil })
    }

    // MARK: - Lifecycle

    @Test("Test The App Root Tracks Its Own Lifecycle")
    func testTheAppRootTracksItsOwnLifecycle() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()
        screen.presenter.schedulePushNotifications()

        #expect(screen.interactor.trackedScreenEventNames == ["AppView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["AppView_Disappear"])
        #expect(screen.interactor.didSchedulePushNotifications)
    }
}

// MARK: - Tab bar

/// The tab bar, and the one thing anything outside the app can ask of it: show a particular tab.
///
/// The selection is keyed on `TabBarScreen.title` rather than an enum case, so a link and the
/// `TabView` have to agree on a string. These tests pin that agreement, and pin that an
/// unrecognised link does nothing at all — landing on an arbitrary tab is worse than ignoring it.
@MainActor
struct AppShellTabBarPresenterTests {

    private final class Interactor: SpyGlobalInteractor, TabBarInteractor {
        var activeSession: WorkoutSessionModel?
        var draftMeal: MealLogModel?
        var activityNotifications: [ActivityNotificationModel] = []
        var incomingFollowRequests: [FollowRequestModel] = []
        /// The real one is `PushManager`; its gating is covered in `PushPendingDeepLinkTests`.
        var pendingDeepLink: DeepLink?

        func consumePendingDeepLink() -> DeepLink? {
            defer { pendingDeepLink = nil }
            return pendingDeepLink
        }

        private(set) var trackedParameters: [[String: Any]] = []

        override func trackEvent(eventName: String, parameters: [String: Any]?, type: LogType) {
            super.trackEvent(eventName: eventName, parameters: parameters, type: type)
            trackedParameters.append(parameters ?? [:])
        }
    }

    private final class Router: TabBarRouter {
        let router: AnyRouter = TestRouting.anyRouter
        func showWorkoutTrackerView() { }

        func showAlert(error: Error) { }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
    }

    private struct Screen {
        let presenter: TabBarPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: TabBarPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func meal() -> MealLogModel {
        MealLogModel(authorId: "user-1", dayKey: "2026-03-04", date: Date(timeIntervalSince1970: 0), items: [])
    }

    /// The Dashboard tab's badge is the unread count — a read notification, or a follow someone
    /// has already seen, must not keep the badge up.
    @Test("Test The Dashboard Badge Counts Only Unread Activity")
    func testTheDashboardBadgeCountsOnlyUnreadActivity() {
        let screen = makeScreen()
        #expect(screen.presenter.unreadActivityCount == 0)

        screen.interactor.activityNotifications = [
            activity(id: "1", type: .like, isRead: false),
            activity(id: "2", type: .follow, isRead: false),
            activity(id: "3", type: .comment, isRead: true)
        ]

        #expect(screen.presenter.unreadActivityCount == 2)
    }

    /// A follow request waiting on an answer is something to act on, so it counts like unread activity.
    @Test("Test The Dashboard Badge Includes Pending Follow Requests")
    func testTheDashboardBadgeIncludesPendingFollowRequests() {
        let screen = makeScreen()
        screen.interactor.activityNotifications = [activity(id: "1", type: .like, isRead: false)]
        screen.interactor.incomingFollowRequests = [
            FollowRequestModel(requesterId: "r1", requesterName: "R1", requesterImageUrl: nil, dateCreated: Date(), status: .pending),
            FollowRequestModel(requesterId: "r2", requesterName: "R2", requesterImageUrl: nil, dateCreated: Date(), status: .pending)
        ]

        #expect(screen.presenter.unreadActivityCount == 3)
    }

    private func activity(
        id: String,
        type: ActivityNotificationModel.ActivityType,
        isRead: Bool
    ) -> ActivityNotificationModel {
        ActivityNotificationModel(
            id: id, type: type, actorId: "a", actorName: "A", actorImageUrl: nil,
            sessionId: "", sessionAuthorId: "user-1", commentText: nil, dateCreated: Date(), isRead: isRead
        )
    }

    // MARK: - Where the app starts

    /// The tab bar opens on the Dashboard. Anyone who has not been sent anywhere lands here.
    @Test("Test The Tab Bar Opens On The Dashboard")
    func testTheTabBarOpensOnTheDashboard() {
        let screen = makeScreen()

        #expect(screen.presenter.selectedTabTitle == "Dashboard")
    }

    // MARK: - Deep links

    /// A `compound://tab/...` link selects that tab. The title is what the `TabView` matches on, so
    /// this is the contract between the link and the UI.
    @Test("Test A Deep Link Selects The Tab It Names")
    func testADeepLinkSelectsTheTabItNames() throws {
        let screen = makeScreen()

        screen.presenter.onOpenURL(try #require(URL(string: "compound://tab/nutrition")))

        #expect(screen.presenter.selectedTabTitle == "Nutrition")
        #expect(screen.interactor.trackedEventNames == ["TabBarView_DeepLink_Tab"])
        #expect(screen.interactor.trackedParameters.first?["tab"] as? String == "nutrition")
    }

    /// The older query-string spelling still works, because links in that shape may already be out
    /// in the world and a link that silently does nothing looks like a broken app.
    @Test("Test The Older Query Style Link Still Works")
    func testTheOlderQueryStyleLinkStillWorks() throws {
        let screen = makeScreen()

        screen.presenter.onOpenURL(try #require(URL(string: "compound://tab?name=training")))

        #expect(screen.presenter.selectedTabTitle == "Training")
    }

    /// A link naming a tab that does not exist leaves the user where they were. Guessing would drop
    /// them somewhere they did not ask for, mid-whatever they were doing.
    @Test("Test An Unrecognised Link Leaves The Tab Alone")
    func testAnUnrecognisedLinkLeavesTheTabAlone() throws {
        let screen = makeScreen()
        screen.presenter.selectedTabTitle = "Training"

        screen.presenter.onOpenURL(try #require(URL(string: "compound://tab/sleep")))
        screen.presenter.onOpenURL(try #require(URL(string: "https://example.com/tab/nutrition")))

        #expect(screen.presenter.selectedTabTitle == "Training")
        #expect(screen.interactor.trackedEventNames == [
            "TabBarView_DeepLink_Unrecognised",
            "TabBarView_DeepLink_Unrecognised"
        ])
    }

    /// A push tap and a link have to mean the same thing, or a notification sends the user
    /// somewhere other than the thing it was about.
    @Test("Test A Push Payload Selects The Same Tab As A Link")
    func testAPushPayloadSelectsTheSameTabAsALink() {
        let screen = makeScreen()

        screen.interactor.pendingDeepLink = DeepLink(pushUserInfo: ["deep_link": "compound://tab/analytics"])
        screen.presenter.onPushNotificationReceived()

        #expect(screen.presenter.selectedTabTitle == "Analytics")
    }

    /// The in-app route: the Dashboard's empty feed sending the user to the Search tab's people
    /// search, without iOS prompting to open the app from itself.
    @Test("Test An In App Request Selects The Tab")
    func testAnInAppRequestSelectsTheTab() {
        let screen = makeScreen()

        screen.presenter.onSelectTabNotificationReceived(
            Notification(name: Constants.selectTab, object: nil, userInfo: ["tab": "search"])
        )

        #expect(screen.presenter.selectedTabTitle == "Search")
    }

    /// The search tab was called "Add" until it settled on being search. Links and pushes written
    /// against the old name still land on it rather than doing nothing.
    @Test("Test The Old Add Name Still Reaches The Search Tab")
    func testTheOldAddNameStillReachesTheSearchTab() throws {
        let screen = makeScreen()

        screen.presenter.onOpenURL(try #require(URL(string: "compound://tab/add")))
        #expect(screen.presenter.selectedTabTitle == "Search")

        screen.presenter.selectedTabTitle = "Training"
        screen.presenter.onSelectTabNotificationReceived(
            Notification(name: Constants.selectTab, object: nil, userInfo: ["tab": "add"])
        )
        #expect(screen.presenter.selectedTabTitle == "Search")
    }

    /// A push with no destination in it is dropped silently. It is not an error — plenty of
    /// notifications have nowhere in particular to go.
    @Test("Test A Push With No Destination Is Ignored")
    func testAPushWithNoDestinationIsIgnored() {
        let screen = makeScreen()

        screen.interactor.pendingDeepLink = DeepLink(pushUserInfo: ["body": "hello"])
        screen.presenter.onPushNotificationReceived()
        screen.presenter.onSelectTabNotificationReceived(
            Notification(name: Constants.selectTab, object: nil, userInfo: nil)
        )

        #expect(screen.presenter.selectedTabTitle == "Dashboard")
        #expect(screen.interactor.trackedEventNames.isEmpty)
    }

    /// A like, comment or mention push carries the session and its author; the tab bar lands on
    /// the Dashboard, which opens it. A comment or mention also opens the thread.
    @Test("Test A Session Push Parses Its Fields And Selects The Dashboard")
    func testASessionPushParsesItsFieldsAndSelectsTheDashboard() {
        let payload: [AnyHashable: Any] = ["tab": "dashboard", "type": "mention", "session_id": "s1", "session_author_id": "u1", "actor_id": "a1"]
        #expect(DeepLink(pushUserInfo: payload) == .session(id: "s1", authorId: "u1", openComments: true))
        #expect(DeepLink(pushUserInfo: ["type": "like", "session_id": "s1", "session_author_id": "u1"]) == .session(id: "s1", authorId: "u1", openComments: false))
        // A follow has no session, so it is just the Dashboard tab.
        #expect(DeepLink(pushUserInfo: ["tab": "dashboard", "type": "follow", "session_id": "", "session_author_id": ""]) == .tab(.dashboard))

        let screen = makeScreen()
        screen.presenter.selectedTabTitle = "Training"
        screen.interactor.pendingDeepLink = DeepLink(pushUserInfo: payload)
        screen.presenter.onPushNotificationReceived()

        #expect(screen.presenter.selectedTabTitle == "Dashboard")
        #expect(screen.interactor.trackedEventNames == ["TabBarView_DeepLink_Session"])
    }

    /// A follow-request push lands on the Dashboard and asks it to open the notifications screen,
    /// even if it also carries a tab.
    @Test("Test A Follow Request Push Opens Notifications From The Dashboard")
    func testAFollowRequestPushOpensNotificationsFromTheDashboard() async {
        let payload: [AnyHashable: Any] = ["tab": "dashboard", "type": "follow_request", "session_id": "", "session_author_id": "", "actor_id": "a1"]
        #expect(DeepLink(pushUserInfo: payload) == .notifications)

        let screen = makeScreen()
        screen.presenter.selectedTabTitle = "Training"
        var opened = false
        let observer = NotificationCenter.default.addObserver(forName: Constants.openNotifications, object: nil, queue: .main) { _ in
            opened = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        screen.interactor.pendingDeepLink = DeepLink(pushUserInfo: payload)
        screen.presenter.onPushNotificationReceived()

        #expect(await TestManagers.eventually { opened })
        #expect(screen.presenter.selectedTabTitle == "Dashboard")
        #expect(screen.interactor.trackedEventNames == ["TabBarView_DeepLink_Notifications"])
    }

    /// A push tapped to launch the app is waiting before the tab bar exists; the tab bar takes it
    /// when it appears, and only once — a later appear or broadcast must not replay it.
    @Test("Test A Pending Push Is Routed On Appear Exactly Once")
    func testAPendingPushIsRoutedOnAppearExactlyOnce() {
        let screen = makeScreen()
        screen.interactor.pendingDeepLink = .tab(.nutrition)

        screen.presenter.onViewAppear()
        #expect(screen.presenter.selectedTabTitle == "Nutrition")

        screen.presenter.selectedTabTitle = "Training"
        screen.presenter.onViewAppear()
        screen.presenter.onPushNotificationReceived()

        #expect(screen.presenter.selectedTabTitle == "Training")
        #expect(screen.interactor.trackedEventNames == ["TabBarView_DeepLink_Tab"])
    }

    // MARK: - The accessory above the tab bar

    /// The accessory is how a user gets back to a workout they walked away from, so it shows
    /// whenever one is running.
    @Test("Test A Running Workout Shows The Tab Accessory")
    func testARunningWorkoutShowsTheTabAccessory() {
        let screen = makeScreen()
        #expect(!screen.presenter.showTabAccessory)

        screen.interactor.activeSession = WorkoutSessionModel.mock

        #expect(screen.presenter.showTabAccessory)
    }

    /// And the same for a meal half-logged — an unfinished draft the user can otherwise not find
    /// their way back to.
    @Test("Test A Draft Meal Shows The Tab Accessory")
    func testADraftMealShowsTheTabAccessory() {
        let screen = makeScreen()

        screen.interactor.draftMeal = meal()

        #expect(screen.presenter.showTabAccessory)
        #expect(screen.presenter.draftMeal?.authorId == "user-1")
    }

    /// With neither, nothing sits above the tab bar taking up room.
    @Test("Test Nothing Running Shows No Tab Accessory")
    func testNothingRunningShowsNoTabAccessory() {
        let screen = makeScreen()

        #expect(!screen.presenter.showTabAccessory)
        #expect(screen.presenter.activeSession == nil)
    }
}

// MARK: - iPad shell

/// The two containers used on a wide screen. Neither decides anything the user can see go wrong
/// beyond which column is in front and whether a workout is running, so the tests are short by
/// design rather than by omission.
@MainActor
struct AppShellSplitViewPresenterTests {

    private final class Interactor: SplitViewContainerInteractor {
        var activeSession: WorkoutSessionModel?
    }

    private final class Router: SplitViewRouter {
        let router: AnyRouter = TestRouting.anyRouter

        func showAlert(error: Error) { }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
    }

    /// On a split screen the sidebar leads, so an iPad opens showing the list rather than an empty
    /// detail pane.
    @Test("Test The Split View Opens On The Sidebar")
    func testTheSplitViewOpensOnTheSidebar() {
        let presenter = SplitViewContainerPresenter(interactor: Interactor(), router: Router())

        #expect(presenter.preferredColumn == .sidebar)
    }

    /// The container reads the running workout straight from the interactor rather than caching it,
    /// so a workout started elsewhere is visible here without the screen being rebuilt.
    @Test("Test The Split View Reads The Running Workout Live")
    func testTheSplitViewReadsTheRunningWorkoutLive() {
        let interactor = Interactor()
        let presenter = SplitViewContainerPresenter(interactor: interactor, router: Router())
        #expect(presenter.activeSession == nil)

        interactor.activeSession = WorkoutSessionModel.mock

        #expect(presenter.activeSession != nil)
    }

    /// `AdaptiveMainPresenter` holds an interactor and a router and does nothing else — the phone
    /// versus iPad choice is made in the view by size class, not here. This stands as the record
    /// that there is no decision in the presenter to test; if behaviour is ever added to it, it
    /// needs tests of its own rather than this one.
    @Test("Test The Adaptive Container Decides Nothing Itself")
    func testTheAdaptiveContainerDecidesNothingItself() {
        let presenter = AdaptiveMainPresenter(interactor: AdaptiveInteractor(), router: AdaptiveRouter())

        #expect(type(of: presenter) == AdaptiveMainPresenter.self)
    }

    private final class AdaptiveInteractor: AdaptiveMainInteractor { }

    private final class AdaptiveRouter: AdaptiveMainRouter {
        let router: AnyRouter = TestRouting.anyRouter

        func showAlert(error: Error) { }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
    }
}
