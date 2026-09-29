//
//  NotificationsScheduledPushTests.swift
//  DialedInUnitTests
//
//  The streak reminder, its hour, and the weekly digest on the notifications screen.
//

import Testing
import Foundation
import SwiftUI
import UserNotifications
@testable import DialedIn

@MainActor
struct NotificationsScheduledPushTests {

    private final class Interactor: SpyGlobalInteractor, NotificationsInteractor {
        var isAuthorised: UNAuthorizationStatus = .authorized
        var activityNotifications: [ActivityNotificationModel] = []
        var currentUser: UserModel? = UserModel(userId: "me")
        var incomingFollowRequests: [FollowRequestModel] = []
        var sentFollowRequestIds: Set<String> = []
        var privateUserSettings = PrivateUserSettings(fcmToken: "tok", socialPushLikes: false)
        var updateError: Error?
        private(set) var writeCount = 0

        func updatePrivateUserSettings(_ change: (inout PrivateUserSettings) -> Void) async throws {
            if let updateError { throw updateError }
            change(&privateUserSettings)
            writeCount += 1
        }

        func fetchIncomingFollowRequests() async throws { }
        func respondToFollowRequest(requesterId: String, accept: Bool) async throws { }
        func getUser(userId: String) async throws -> UserModel { UserModel(userId: userId) }
        func followUser(userId: String) async throws { }
        func unfollowUser(userId: String) async throws { }
        func sendFollowRequest(to user: UserModel) async throws { }
        func cancelFollowRequest(userId: String) async throws { }
        func requestPushAuthorisation() async throws -> Bool { true }
        func canRequestNotificationAuthorisation() async -> Bool { true }
        func removeDeliveredNotifications(ids: [String]) { }
        func checkPushNotificationAuthorisation() async throws -> UNAuthorizationStatus { isAuthorised }
        func fetchActivityNotifications() async throws { }
        func markActivityNotificationsRead() async throws { }
        func deleteActivityNotification(id: String) async throws { }
        func clearAllDeliveredNotifications() { }
        func updateSocialNotificationPreferences(type: ActivityNotificationModel.ActivityType, isEnabled: Bool) async throws { }
        func fetchWorkoutSession(id: String, authorId: String) async throws -> WorkoutSessionModel { throw DevToolsTestError.failed }
        func fetchShare(id: String) async throws -> ShareModel { throw DevToolsTestError.failed }
        // MARK: - GroupedNotifications
        var canLoadMoreActivityNotifications = false
        func fetchMoreActivityNotifications() async throws { }
        func markActivityNotificationsRead(ids: [String]) async throws { }
        func fetchChallenge(id: String) async throws -> ChallengeModel { throw DevToolsTestError.failed }
    }

    private final class Router: NotificationsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertedErrors: [Error] = []

        func showAlert(error: Error) { alertedErrors.append(error) }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
        func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) { }
        func showWorkoutSessionThread(delegate: WorkoutSessionDetailDelegate) { }
        func showSocialProfileView(delegate: SocialProfileDelegate) { }
        func showSharedItemView(delegate: SharedItemDelegate) { }
        func showChallengeDetailView(delegate: ChallengeDetailDelegate) { }
    }

    /// The stored JSON keys, which are what `functions/lib.js` reads.
    private func storedKeys(_ settings: PrivateUserSettings) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any] ?? [:]
    }

    @Test("Test Both Switches Default On And The Hour Defaults To Nineteen")
    func testDefaults() {
        let presenter = NotificationsPresenter(interactor: Interactor(), router: Router())

        #expect(presenter.isStreakReminderEnabled)
        #expect(presenter.isWeeklyDigestEnabled)
        #expect(presenter.streakReminderHour == 19)
    }

    @Test("Test Each Control Writes The Key The Cloud Function Reads And Keeps The Rest")
    func testEachControlWritesItsKey() async throws {
        let interactor = Interactor()
        let presenter = NotificationsPresenter(interactor: interactor, router: Router())

        presenter.isStreakReminderEnabled = false
        await TestManagers.eventually { interactor.writeCount == 1 }
        presenter.streakReminderHour = 7
        await TestManagers.eventually { interactor.writeCount == 2 }
        presenter.isWeeklyDigestEnabled = false
        await TestManagers.eventually { interactor.writeCount == 3 }

        let stored = try storedKeys(interactor.privateUserSettings)
        #expect(stored["social_push_streak_reminder"] as? Bool == false)
        #expect(stored["reminder_hour"] as? Int == 7)
        #expect(stored["social_push_weekly_digest"] as? Bool == false)
        #expect(stored["fcm_token"] as? String == "tok")
        #expect(stored["social_push_likes"] as? Bool == false)
        #expect(!presenter.isStreakReminderEnabled)
        #expect(presenter.streakReminderHour == 7)
        #expect(!presenter.isWeeklyDigestEnabled)
    }

    @Test("Test Timezone Is Stored Under The Key The Cloud Function Reads")
    func testTimezoneKey() throws {
        let stored = try storedKeys(PrivateUserSettings(timezone: "Europe/London"))
        #expect(stored["timezone"] as? String == "Europe/London")
    }

    @Test("Test A Failed Write Shows The Error")
    func testAFailedWriteShowsTheError() async {
        let interactor = Interactor()
        interactor.updateError = DevToolsTestError.failed
        let router = Router()
        let presenter = NotificationsPresenter(interactor: interactor, router: router)

        presenter.isWeeklyDigestEnabled = false
        await TestManagers.eventually { !router.alertedErrors.isEmpty }

        #expect(router.alertedErrors.count == 1)
        #expect(presenter.isWeeklyDigestEnabled)
    }
}
