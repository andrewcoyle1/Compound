//
//  NotificationSettingsPresenterTests.swift
//  CompoundUnitTests
//
//  Notification Settings: the push permission prompt, the Social switches, and the streak
//  reminder, its hour and the weekly digest.
//

import Testing
import Foundation
import SwiftUI
import UserNotifications
@testable import Compound

@MainActor
struct NotificationSettingsPresenterTests {

    private final class Interactor: SpyGlobalInteractor, NotificationSettingsInteractor {
        var isAuthorised: UNAuthorizationStatus = .authorized
        var privateUserSettings = PrivateUserSettings()

        var requestError: Error?
        var checkError: Error?
        /// What the system reports once the request is answered.
        var statusAfterRequest: UNAuthorizationStatus = .authorized
        private(set) var requestCount = 0
        private(set) var checkCount = 0

        func checkPushNotificationAuthorisation() async throws -> UNAuthorizationStatus {
            checkCount += 1
            if let checkError { throw checkError }
            return isAuthorised
        }

        func requestPushAuthorisation() async throws -> Bool {
            requestCount += 1
            if let requestError { throw requestError }
            isAuthorised = statusAfterRequest
            return statusAfterRequest == .authorized
        }

        var preferenceError: Error?
        private(set) var preferenceWrites: [String: Bool] = [:]

        /// Records the private-settings key the real `UserManager` would write, so a test can check
        /// the value lands under the field the Cloud Function reads.
        func updateSocialNotificationPreferences(type: ActivityNotificationModel.ActivityType, isEnabled: Bool) async throws {
            if let preferenceError { throw preferenceError }
            preferenceWrites[PrivateUserSettings.socialPushKey(for: type).rawValue] = isEnabled
        }

        var updateError: Error?
        private(set) var writeCount = 0

        func updatePrivateUserSettings(_ change: (inout PrivateUserSettings) -> Void) async throws {
            if let updateError { throw updateError }
            change(&privateUserSettings)
            writeCount += 1
        }

        /// What the device was last told to schedule, as `CoreInteractor` passes it to `PushManager`.
        private(set) var scheduledComeBack: Bool?
        private(set) var scheduledMeals: Bool?

        func setComeBackReminders(isEnabled: Bool) async throws {
            try await updatePrivateUserSettings { $0.pushComeBackReminders = isEnabled }
            scheduledComeBack = isEnabled
        }

        func setMealReminders(isEnabled: Bool) async throws {
            try await updatePrivateUserSettings { $0.pushMealReminders = isEnabled }
            scheduledMeals = isEnabled
        }
    }

    private final class Router: NotificationSettingsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertedErrors: [Error] = []

        func showAlert(error: Error) { alertedErrors.append(error) }
        // Error alerts carry a title saying what failed; they are the same alert to a test.
        func showAlert(title: String, error: Error) { alertedErrors.append(error) }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
    }

    private struct Screen {
        let presenter: NotificationSettingsPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(_ interactor: Interactor? = nil) -> Screen {
        let interactor = interactor ?? Interactor()
        let router = Router()
        return Screen(
            presenter: NotificationSettingsPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// The stored JSON keys, which are what `functions/lib.js` reads.
    private func storedKeys(_ settings: PrivateUserSettings) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any] ?? [:]
    }

    @Test("Test The Screen Tracks Its Appearance")
    func testTheScreenTracksItsAppearance() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["NotificationSettingsView_Appear"])
    }

    // MARK: - Permission

    /// Never asked: the screen offers to ask, and the switches wait for the answer.
    @Test("Test An Unasked Permission Offers To Ask And Disables The Switches")
    func testAnUnaskedPermissionOffersToAsk() {
        let interactor = Interactor()
        interactor.isAuthorised = .notDetermined
        let screen = makeScreen(interactor)

        #expect(screen.presenter.permissionPrompt == .askFirst)
        #expect(!screen.presenter.canChangeSwitches)
    }

    /// Refused: only the Settings app can undo it, so the switches must not look as if they work.
    @Test("Test A Denied Permission Points To Settings And Disables The Switches")
    func testADeniedPermissionDisablesTheSwitches() {
        let interactor = Interactor()
        interactor.isAuthorised = .denied
        let screen = makeScreen(interactor)

        #expect(screen.presenter.permissionPrompt == .denied)
        #expect(!screen.presenter.canChangeSwitches)
    }

    /// Allowed, including quietly: nothing to prompt for, and every switch works.
    @Test("Test An Allowed Permission Shows No Prompt And Enables The Switches", arguments: [UNAuthorizationStatus.authorized, .provisional, .ephemeral])
    func testAnAllowedPermissionEnablesTheSwitches(status: UNAuthorizationStatus) {
        let interactor = Interactor()
        interactor.isAuthorised = status
        let screen = makeScreen(interactor)

        #expect(screen.presenter.permissionPrompt == nil)
        #expect(screen.presenter.canChangeSwitches)
    }

    /// Granting permission reads the status back straight away, so the prompt gives way to working
    /// switches without leaving and coming back.
    @Test("Test Granting Permission Enables The Switches Immediately")
    func testGrantingPermissionEnablesTheSwitchesImmediately() async {
        let interactor = Interactor()
        interactor.isAuthorised = .notDetermined
        let screen = makeScreen(interactor)

        screen.presenter.onRequestNotificationsPressed()

        #expect(await TestManagers.eventually { screen.interactor.checkCount == 1 })
        #expect(screen.interactor.requestCount == 1)
        #expect(screen.presenter.canChangeSwitches)
        #expect(screen.router.alertedErrors.isEmpty)
    }

    /// A permission request that throws tells the user. This catch used to be empty: the button
    /// did nothing visible and there was no way to tell a refusal from a failure.
    @Test("Test A Failed Permission Request Is Not Swallowed")
    func testAFailedPermissionRequestIsNotSwallowed() async {
        let screen = makeScreen()
        screen.interactor.requestError = DevToolsTestError.failed

        screen.presenter.onRequestNotificationsPressed()

        #expect(await TestManagers.eventually { screen.router.alertedErrors.count == 1 })
        #expect(screen.interactor.checkCount == 0)
    }

    /// Checking the current status decides between the prompt and the switches, so a check that
    /// fails has to surface rather than leave the screen guessing.
    @Test("Test A Failed Permission Check Is Reported")
    func testAFailedPermissionCheckIsReported() async {
        let screen = makeScreen()
        screen.interactor.checkError = DevToolsTestError.failed

        await screen.presenter.checkPermissions()

        #expect(screen.router.alertedErrors.count == 1)
    }

    /// And a check that works reports nothing, so the screen only nags when something is wrong.
    @Test("Test A Successful Permission Check Says Nothing")
    func testASuccessfulPermissionCheckSaysNothing() async {
        let screen = makeScreen()

        await screen.presenter.checkPermissions()

        #expect(screen.router.alertedErrors.isEmpty)
        #expect(screen.presenter.authorizationStatus == .authorized)
    }

    /// Coming back from the Settings app re-reads the status, since that is where a denial is undone.
    @Test("Test Returning To The App Re-Reads The Permission")
    func testReturningToTheAppRereadsThePermission() async {
        let interactor = Interactor()
        interactor.isAuthorised = .denied
        let screen = makeScreen(interactor)

        interactor.isAuthorised = .authorized
        screen.presenter.onSceneBecameActive()

        #expect(await TestManagers.eventually { screen.interactor.checkCount == 1 })
        #expect(screen.presenter.canChangeSwitches)
    }

    // MARK: - Social push switches

    /// A user who has never written the private settings document has no preference fields, and
    /// must keep getting pushes: every switch reads on.
    @Test("Test Social Push Switches Default To On When The Private Settings Have No Preferences")
    func testSocialPushSwitchesDefaultToOn() {
        let screen = makeScreen()
        #expect(screen.presenter.isLikesPushEnabled)
        #expect(screen.presenter.isCommentsPushEnabled)
        #expect(screen.presenter.isMentionsPushEnabled)
        #expect(screen.presenter.isFollowsPushEnabled)
        #expect(screen.presenter.isNudgesPushEnabled)
        #expect(screen.presenter.isSharesPushEnabled)
        #expect(screen.presenter.isChallengesPushEnabled)

        screen.interactor.privateUserSettings = PrivateUserSettings(socialPushLikes: false, socialPushFollows: true)
        #expect(!screen.presenter.isLikesPushEnabled)
        #expect(screen.presenter.isCommentsPushEnabled)
        #expect(screen.presenter.isFollowsPushEnabled)
    }

    /// Each switch writes its own key, and only that key, the moment it flips. The key names are
    /// the contract with `SOCIAL_PUSH_PREFERENCE_KEYS` in functions/lib.js. The event keeps its
    /// `NotificationsView_` name from before the switches moved, so its funnel carries on.
    @Test("Test Flipping A Social Push Switch Writes Its Own Key")
    func testFlippingASocialPushSwitchWritesItsOwnKey() async {
        let screen = makeScreen()

        screen.presenter.isCommentsPushEnabled = false
        #expect(await TestManagers.eventually { screen.interactor.preferenceWrites == ["social_push_comments": false] })

        screen.presenter.isLikesPushEnabled = false
        screen.presenter.isFollowsPushEnabled = false
        screen.presenter.isNudgesPushEnabled = false
        let expected = ["social_push_comments": false, "social_push_likes": false, "social_push_follows": false, "social_push_nudges": false]
        #expect(await TestManagers.eventually { screen.interactor.preferenceWrites == expected })
        #expect(screen.interactor.trackedEventNames.contains("NotificationsView_SocialPush_Toggle"))
        #expect(screen.router.alertedErrors.isEmpty)
    }

    /// The event carries the same parameters as before the move.
    @Test("Test The Social Push Event Keeps Its Parameters")
    func testTheSocialPushEventKeepsItsParameters() {
        let event = NotificationSettingsPresenter.Event.socialPushToggled(type: .like, isEnabled: false)

        #expect(event.eventName == "NotificationsView_SocialPush_Toggle")
        #expect(event.parameters?["type"] as? String == ActivityNotificationModel.ActivityType.like.rawValue)
        #expect(event.parameters?["is_enabled"] as? Bool == false)
    }

    /// A write that fails says so, and the switch still reads the stored value rather than the
    /// one the user tried to set.
    @Test("Test A Failed Social Push Write Shows An Alert")
    func testAFailedSocialPushWriteShowsAnAlert() async {
        let screen = makeScreen()
        screen.interactor.preferenceError = DevToolsTestError.failed

        screen.presenter.isLikesPushEnabled = false

        #expect(await TestManagers.eventually { screen.router.alertedErrors.count == 1 })
        #expect(screen.interactor.preferenceWrites.isEmpty)
        #expect(screen.presenter.isLikesPushEnabled)
    }

    // MARK: - Reminders

    /// Changed: the streak reminder used to default on. It is now off until chosen (offered once at
    /// a 3-day streak), and the two local reminders have joined: come-back on, meals off.
    @Test("Test Reminder Defaults: Digest And Come-Back On, Streak And Meals Off, Hour Nineteen")
    func testReminderDefaults() {
        let screen = makeScreen()

        #expect(!screen.presenter.isStreakReminderEnabled)
        #expect(screen.presenter.isWeeklyDigestEnabled)
        #expect(screen.presenter.isComeBackRemindersEnabled)
        #expect(!screen.presenter.isMealRemindersEnabled)
        #expect(screen.presenter.streakReminderHour == 19)
    }

    @Test("Test The Local Reminder Switches Save Their Keys And Reschedule The Device")
    func testLocalReminderSwitches() async throws {
        let screen = makeScreen()

        screen.presenter.isComeBackRemindersEnabled = false
        #expect(await TestManagers.eventually { screen.interactor.scheduledComeBack == false })
        screen.presenter.isMealRemindersEnabled = true
        #expect(await TestManagers.eventually { screen.interactor.scheduledMeals == true })

        let stored = try storedKeys(screen.interactor.privateUserSettings)
        #expect(stored["push_come_back_reminders"] as? Bool == false)
        #expect(stored["push_meal_reminders"] as? Bool == true)
        #expect(!screen.presenter.isComeBackRemindersEnabled)
        #expect(screen.presenter.isMealRemindersEnabled)
        let expectedEvents = ["NotificationSettingsView_ComeBackReminders_Toggle", "NotificationSettingsView_MealReminders_Toggle"]
        // Each write also logs SaveSetting Start and Success, which can interleave with the next toggle.
        #expect(screen.interactor.trackedEventNames.filter { !$0.contains("_SaveSetting_") } == expectedEvents)
        #expect(await TestManagers.eventually {
            screen.interactor.trackedEventNames.filter { $0 == "NotificationSettingsView_SaveSetting_Success" }.count == 2
        })
    }

    @Test("Test Each Reminder Control Writes The Key The Cloud Function Reads And Keeps The Rest")
    func testEachReminderControlWritesItsKey() async throws {
        let interactor = Interactor()
        interactor.privateUserSettings = PrivateUserSettings(fcmToken: "tok", socialPushLikes: false)
        let screen = makeScreen(interactor)

        screen.presenter.isStreakReminderEnabled = true
        await TestManagers.eventually { interactor.writeCount == 1 }
        screen.presenter.streakReminderHour = 7
        await TestManagers.eventually { interactor.writeCount == 2 }
        screen.presenter.isWeeklyDigestEnabled = false
        await TestManagers.eventually { interactor.writeCount == 3 }

        let stored = try storedKeys(interactor.privateUserSettings)
        #expect(stored["social_push_streak_reminder"] as? Bool == true)
        #expect(stored["reminder_hour"] as? Int == 7)
        #expect(stored["social_push_weekly_digest"] as? Bool == false)
        #expect(stored["fcm_token"] as? String == "tok")
        #expect(stored["social_push_likes"] as? Bool == false)
        #expect(screen.presenter.isStreakReminderEnabled)
        #expect(screen.presenter.streakReminderHour == 7)
        #expect(!screen.presenter.isWeeklyDigestEnabled)
        let expectedEvents = ["NotificationsView_StreakReminder_Toggle", "NotificationsView_ReminderHour_Changed", "NotificationsView_WeeklyDigest_Toggle"]
        #expect(interactor.trackedEventNames.filter { !$0.contains("_SaveSetting_") } == expectedEvents)
        #expect(await TestManagers.eventually {
            interactor.trackedEventNames.filter { $0 == "NotificationSettingsView_SaveSetting_Success" }.count == 3
        })
    }

    @Test("Test Timezone Is Stored Under The Key The Cloud Function Reads")
    func testTimezoneKey() throws {
        let stored = try storedKeys(PrivateUserSettings(timezone: "Europe/London"))
        #expect(stored["timezone"] as? String == "Europe/London")
    }

    @Test("Test A Failed Reminder Write Shows The Error")
    func testAFailedReminderWriteShowsTheError() async {
        let screen = makeScreen()
        screen.interactor.updateError = DevToolsTestError.failed

        screen.presenter.isWeeklyDigestEnabled = false
        await TestManagers.eventually { !screen.router.alertedErrors.isEmpty }

        #expect(screen.router.alertedErrors.count == 1)
        #expect(screen.presenter.isWeeklyDigestEnabled)
    }
}
