//
//  NotificationTapThroughTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 24/09/2026.
//

import Testing
import SwiftUI
import UserNotifications
@testable import DialedIn

/// Tapping a row in the notifications list goes to what it is about: a like to the session, a
/// comment or mention to the session with its thread on top, a follow to the follower's profile.
/// Anything that cannot be fetched says so rather than doing nothing.
@MainActor
struct NotificationTapThroughTests {

    private final class Interactor: SpyGlobalInteractor, NotificationsInteractor {
        var isAuthorised: UNAuthorizationStatus = .authorized
        var activityNotifications: [ActivityNotificationModel] = []
        var currentUser: UserModel? = UserModel(userId: "me")
        var sessions: [WorkoutSessionModel] = []
        var users: [UserModel] = []
        private(set) var sessionRequests: [String] = []

        func requestPushAuthorisation() async throws -> Bool { true }
        func canRequestNotificationAuthorisation() async -> Bool { true }
        func removeDeliveredNotifications(ids: [String]) { }
        func checkPushNotificationAuthorisation() async throws -> UNAuthorizationStatus { isAuthorised }
        func fetchActivityNotifications() async throws { }
        func markActivityNotificationsRead() async throws { }
        func deleteActivityNotification(id: String) async throws { }
        func clearAllDeliveredNotifications() { }
        func updateSocialNotificationPreferences(type: ActivityNotificationModel.ActivityType, isEnabled: Bool) async throws { }
        var privateUserSettings = PrivateUserSettings()
        var incomingFollowRequests: [FollowRequestModel] = []
        var sentFollowRequestIds: Set<String> = []
        func fetchIncomingFollowRequests() async throws { }
        func respondToFollowRequest(requesterId: String, accept: Bool) async throws { }
        func followUser(userId: String) async throws { }
        func unfollowUser(userId: String) async throws { }
        func sendFollowRequest(to user: UserModel) async throws { }
        func cancelFollowRequest(userId: String) async throws { }

        func fetchWorkoutSession(id: String, authorId: String) async throws -> WorkoutSessionModel {
            sessionRequests.append("\(id)|\(authorId)")
            guard let session = sessions.first(where: { $0.id == id }) else { throw URLError(.fileDoesNotExist) }
            return session
        }

        var shares: [ShareModel] = []

        func fetchShare(id: String) async throws -> ShareModel {
            guard let share = shares.first(where: { $0.id == id }) else { throw URLError(.fileDoesNotExist) }
            return share
        }
        func updatePrivateUserSettings(_ change: (inout PrivateUserSettings) -> Void) async throws { change(&privateUserSettings) }

        var challenges: [ChallengeModel] = []

        func fetchChallenge(id: String) async throws -> ChallengeModel {
            guard let challenge = challenges.first(where: { $0.id == id }) else { throw URLError(.fileDoesNotExist) }
            return challenge
        }

        func getUser(userId: String) async throws -> UserModel {
            guard let user = users.first(where: { $0.userId == userId }) else { throw URLError(.fileDoesNotExist) }
            return user
        }
        // MARK: - GroupedNotifications
        var canLoadMoreActivityNotifications = false
        private(set) var markedReadIds: [[String]] = []
        private(set) var fetchMoreCount = 0
        func fetchMoreActivityNotifications() async throws { fetchMoreCount += 1 }
        func markActivityNotificationsRead(ids: [String]) async throws { markedReadIds.append(ids) }
    }

    private final class Router: NotificationsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var alertTitles: [String] = []

        func showAlert(error: Error) { alertTitles.append("error") }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
        func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) { shown.append("session:\(delegate.initialSession.id)") }
        func showWorkoutSessionThread(delegate: WorkoutSessionDetailDelegate) { shown.append("thread:\(delegate.initialSession.id)") }
        func showSocialProfileView(delegate: SocialProfileDelegate) { shown.append("profile:\(delegate.user.userId)") }
        func showSharedItemView(delegate: SharedItemDelegate) { shown.append("share:\(delegate.share.id)|\(delegate.senderName)") }
        func showChallengeDetailView(delegate: ChallengeDetailDelegate) { shown.append("challenge:\(delegate.challenge.id)") }
    }

    private struct Screen {
        let presenter: NotificationsPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        interactor.sessions = [DashboardFixture.session(id: "s1", author: "author", on: DashboardFixture.date(day: 2))]
        interactor.users = [UserModel(userId: "fan")]
        let router = Router()
        return Screen(presenter: NotificationsPresenter(interactor: interactor, router: router), interactor: interactor, router: router)
    }

    private func notification(_ type: ActivityNotificationModel.ActivityType, sessionId: String = "s1") -> ActivityNotificationModel {
        ActivityNotificationModel(
            id: "n-\(type.rawValue)",
            type: type,
            actorId: "fan",
            actorName: "Fan",
            actorImageUrl: nil,
            sessionId: type == .follow ? "" : sessionId,
            sessionAuthorId: "author",
            commentText: nil,
            dateCreated: Date(timeIntervalSince1970: 0),
            isRead: false
        )
    }

    @Test("Test Tapping A Like Opens The Session")
    func testTappingALikeOpensTheSession() async {
        let screen = makeScreen()

        screen.presenter.onNotificationPressed(notification(.like))
        await TestManagers.eventually { !screen.router.shown.isEmpty }

        #expect(screen.router.shown == ["session:s1"])
        #expect(screen.interactor.sessionRequests == ["s1|author"])
        #expect(screen.interactor.trackedEventNames.contains("NotificationsView_Notification_Pressed"))
    }

    @Test("Test Tapping A Comment Or Mention Opens The Thread")
    func testTappingACommentOrMentionOpensTheThread() async {
        let screen = makeScreen()

        screen.presenter.onNotificationPressed(notification(.comment))
        await TestManagers.eventually { screen.router.shown.count == 1 }
        screen.presenter.onNotificationPressed(notification(.mention))
        await TestManagers.eventually { screen.router.shown.count == 2 }

        #expect(screen.router.shown == ["thread:s1", "thread:s1"])
    }

    @Test("Test Tapping A Follow Opens The Followers Profile")
    func testTappingAFollowOpensTheFollowersProfile() async {
        let screen = makeScreen()

        screen.presenter.onNotificationPressed(notification(.follow))
        await TestManagers.eventually { !screen.router.shown.isEmpty }

        #expect(screen.router.shown == ["profile:fan"])
        #expect(screen.interactor.sessionRequests.isEmpty)
    }

    @Test("Test A Failed Fetch Alerts And Routes Nowhere")
    func testAFailedFetchAlertsAndRoutesNowhere() async {
        let screen = makeScreen()
        screen.interactor.users = []

        screen.presenter.onNotificationPressed(notification(.comment, sessionId: "deleted"))
        screen.presenter.onNotificationPressed(notification(.follow))
        await TestManagers.eventually { screen.router.alertTitles.count == 2 }

        #expect(screen.router.alertTitles == ["Unable to Open", "Unable to Open"])
        #expect(screen.router.shown.isEmpty)
    }

    // MARK: - Sharing

    @Test("Test Tapping A Share Opens The Shared Item")
    func testTappingAShareOpensTheSharedItem() async {
        let screen = makeScreen()
        screen.interactor.shares = ShareModel.mocks
        var share = notification(.share)
        share.shareId = "mock_share_program"

        screen.presenter.onNotificationPressed(share)
        await TestManagers.eventually { !screen.router.shown.isEmpty }

        #expect(screen.router.shown == ["share:mock_share_program|Fan"])
        #expect(screen.interactor.sessionRequests.isEmpty)
    }

    @Test("Test A Share That Cannot Be Read Alerts")
    func testAShareThatCannotBeReadAlerts() async {
        let screen = makeScreen()
        var share = notification(.share)
        share.shareId = "gone"

        screen.presenter.onNotificationPressed(share)
        await TestManagers.eventually { !screen.router.alertTitles.isEmpty }

        #expect(screen.router.alertTitles == ["Unable to Open"])
        #expect(screen.router.shown.isEmpty)
    }

    // MARK: - GroupedNotifications

    private func like(_ id: String, actor: String, isRead: Bool = false, minutesAgo: Double = 0) -> ActivityNotificationModel {
        ActivityNotificationModel(
            id: id, type: .like, actorId: actor, actorName: actor, actorImageUrl: nil,
            sessionId: "s1", sessionAuthorId: "author", commentText: nil,
            dateCreated: Date(timeIntervalSince1970: 100_000 - minutesAgo * 60), isRead: isRead
        )
    }

    @Test("Test Tapping A Group Opens Its Session Once")
    func testTappingAGroupOpensItsSessionOnce() async throws {
        let screen = makeScreen()
        screen.interactor.activityNotifications = [like("a", actor: "Alice"), like("b", actor: "Bob", minutesAgo: 5)]
        let group = try #require(screen.presenter.notificationGroups.first)
        #expect(screen.presenter.notificationGroups.count == 1)

        screen.presenter.onGroupPressed(group)
        await TestManagers.eventually { !screen.router.shown.isEmpty }

        #expect(screen.router.shown == ["session:s1"])
        #expect(screen.interactor.sessionRequests == ["s1|author"])
    }

    @Test("Test Tapping A Group Marks Only Its Unread Members Read")
    func testTappingAGroupMarksOnlyItsUnreadMembersRead() async throws {
        let screen = makeScreen()
        screen.interactor.activityNotifications = [
            like("a", actor: "Alice"),
            like("b", actor: "Bob", isRead: true, minutesAgo: 5),
            like("c", actor: "Cara", minutesAgo: 10)
        ]
        let group = try #require(screen.presenter.notificationGroups.first)

        screen.presenter.onGroupPressed(group)
        await TestManagers.eventually { !screen.interactor.markedReadIds.isEmpty }

        #expect(screen.interactor.markedReadIds == [["a", "c"]])
    }

    @Test("Test Tapping A Read Group Writes Nothing")
    func testTappingAReadGroupWritesNothing() async throws {
        let screen = makeScreen()
        screen.interactor.activityNotifications = [like("a", actor: "Alice", isRead: true)]
        let group = try #require(screen.presenter.notificationGroups.first)

        screen.presenter.onGroupPressed(group)
        await TestManagers.eventually { !screen.router.shown.isEmpty }

        #expect(screen.interactor.markedReadIds.isEmpty)
    }

    @Test("Test Load More Fetches The Next Page")
    func testLoadMoreFetchesTheNextPage() async {
        let screen = makeScreen()
        screen.interactor.canLoadMoreActivityNotifications = true
        #expect(screen.presenter.canLoadMore)

        screen.presenter.onLoadMorePressed()
        await TestManagers.eventually { screen.interactor.fetchMoreCount == 1 }

        #expect(screen.interactor.fetchMoreCount == 1)
        #expect(screen.interactor.trackedEventNames.contains("NotificationsView_LoadMore_Pressed"))
    }

    // MARK: - Challenges

    @Test("Test Tapping A Finished Challenge Opens Its Standings")
    func testTappingAFinishedChallengeOpensItsStandings() async {
        let screen = makeScreen()
        screen.interactor.challenges = ChallengeModel.mocks
        var finished = notification(.challengeComplete)
        finished.challengeId = "mock_challenge_2"

        screen.presenter.onNotificationPressed(finished)
        await TestManagers.eventually { !screen.router.shown.isEmpty }

        #expect(screen.router.shown == ["challenge:mock_challenge_2"])
        #expect(screen.interactor.sessionRequests.isEmpty)
    }
}
