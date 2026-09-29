//
//  NotificationsFollowRequestTests.swift
//  DialedInUnitTests
//
//  Follow requests answered from the top of the notifications screen, and following back from a
//  follow notification.
//

import Testing
import Foundation
import SwiftUI
import UserNotifications
@testable import DialedIn

@MainActor
struct NotificationsFollowRequestTests {

    private final class Interactor: SpyGlobalInteractor, NotificationsInteractor {
        var isAuthorised: UNAuthorizationStatus = .authorized
        var activityNotifications: [ActivityNotificationModel] = []
        var currentUser: UserModel? = UserModel(userId: "me")
        var incomingFollowRequests: [FollowRequestModel] = []
        var sentFollowRequestIds: Set<String> = []
        var usersById: [String: UserModel] = [:]
        var respondError: Error?

        private(set) var fetchedRequestsCount = 0
        /// Each answer as the status the real service writes: "requesterId:accepted" or ":declined".
        private(set) var statusWrites: [String] = []
        private(set) var followed: [String] = []
        private(set) var requested: [String] = []

        func fetchIncomingFollowRequests() async throws { fetchedRequestsCount += 1 }

        func respondToFollowRequest(requesterId: String, accept: Bool) async throws {
            if let respondError { throw respondError }
            let status: FollowRequestModel.Status = accept ? .accepted : .declined
            statusWrites.append("\(requesterId):\(status.rawValue)")
            incomingFollowRequests.removeAll { $0.requesterId == requesterId }
        }

        func getUser(userId: String) async throws -> UserModel {
            guard let user = usersById[userId] else { throw DevToolsTestError.failed }
            return user
        }

        func followUser(userId: String) async throws {
            followed.append(userId)
            currentUser = UserModel(userId: "me", followingIds: (currentUser?.followingIds ?? []) + [userId])
        }
        func unfollowUser(userId: String) async throws { }
        func sendFollowRequest(to user: UserModel) async throws {
            requested.append(user.userId)
            sentFollowRequestIds.insert(user.userId)
        }
        func cancelFollowRequest(userId: String) async throws { sentFollowRequestIds.remove(userId) }

        func requestPushAuthorisation() async throws -> Bool { true }
        func canRequestNotificationAuthorisation() async -> Bool { true }
        func removeDeliveredNotifications(ids: [String]) { }
        func checkPushNotificationAuthorisation() async throws -> UNAuthorizationStatus { isAuthorised }
        func fetchActivityNotifications() async throws { }
        func markActivityNotificationsRead() async throws { }
        var deleteError: Error?
        func deleteActivityNotification(id: String) async throws {
            if let deleteError { throw deleteError }
        }
        func clearAllDeliveredNotifications() { }
        func updateSocialNotificationPreferences(type: ActivityNotificationModel.ActivityType, isEnabled: Bool) async throws { }
        var privateUserSettings = PrivateUserSettings()
        func fetchWorkoutSession(id: String, authorId: String) async throws -> WorkoutSessionModel { throw DevToolsTestError.failed }
        func fetchShare(id: String) async throws -> ShareModel { throw DevToolsTestError.failed }
        func fetchChallenge(id: String) async throws -> ChallengeModel { throw DevToolsTestError.failed }
        func updatePrivateUserSettings(_ change: (inout PrivateUserSettings) -> Void) async throws { change(&privateUserSettings) }
        // MARK: - GroupedNotifications
        var canLoadMoreActivityNotifications = false
        func fetchMoreActivityNotifications() async throws { }
        func markActivityNotificationsRead(ids: [String]) async throws { }
    }

    private final class Router: NotificationsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []

        func showAlert(error: Error) { }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
        func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) { }
        func showWorkoutSessionThread(delegate: WorkoutSessionDetailDelegate) { }
        func showSocialProfileView(delegate: SocialProfileDelegate) { }
        func showSharedItemView(delegate: SharedItemDelegate) { }
        func showChallengeDetailView(delegate: ChallengeDetailDelegate) { }
    }

    private func request(_ id: String) -> FollowRequestModel {
        FollowRequestModel(requesterId: id, requesterName: id, requesterImageUrl: nil, dateCreated: Date(timeIntervalSince1970: 0), status: .pending)
    }

    private func follow(from actorId: String) -> ActivityNotificationModel {
        ActivityNotificationModel(
            id: "follow_\(actorId)", type: .follow, actorId: actorId, actorName: actorId, actorImageUrl: nil,
            sessionId: "", sessionAuthorId: "me", commentText: nil, dateCreated: Date(timeIntervalSince1970: 0), isRead: false
        )
    }

    /// Requests arrive through the user manager's live listener, so opening the screen does not
    /// fetch them; only pull-to-refresh does.
    @Test("Test Only Pull To Refresh Fetches Incoming Requests")
    func testOnlyPullToRefreshFetchesIncomingRequests() async {
        let interactor = Interactor()
        let presenter = NotificationsPresenter(interactor: interactor, router: Router())

        await presenter.loadNotifications()
        #expect(interactor.fetchedRequestsCount == 0)

        await presenter.onPullToRefresh()
        #expect(interactor.fetchedRequestsCount == 1)
    }

    /// Accept and decline each write the request's status and nothing else; the follow itself is the
    /// Cloud Function's job. An answered request leaves the list.
    @Test("Test Accept And Decline Write The Status")
    func testAcceptAndDeclineWriteTheStatus() async {
        let interactor = Interactor()
        interactor.incomingFollowRequests = [request("r1"), request("r2")]
        let presenter = NotificationsPresenter(interactor: interactor, router: Router())

        presenter.onAcceptRequestPressed(request("r1"))
        presenter.onDeclineRequestPressed(request("r2"))
        await TestManagers.eventually { interactor.statusWrites.count == 2 }

        #expect(Set(interactor.statusWrites) == ["r1:accepted", "r2:declined"])
        #expect(presenter.incomingFollowRequests.isEmpty)
        #expect(interactor.followed.isEmpty)
    }

    @Test("Test A Failed Answer Shows An Alert And Keeps The Request")
    func testAFailedAnswerShowsAnAlertAndKeepsTheRequest() async {
        let interactor = Interactor()
        interactor.respondError = DevToolsTestError.failed
        interactor.incomingFollowRequests = [request("r1")]
        let router = Router()
        let presenter = NotificationsPresenter(interactor: interactor, router: router)

        presenter.onAcceptRequestPressed(request("r1"))
        await TestManagers.eventually { !router.alertTitles.isEmpty }

        #expect(router.alertTitles == ["Unable to answer request"])
        #expect(presenter.incomingFollowRequests.map(\.requesterId) == ["r1"])
    }

    /// Follow back reads the actor's profile first: a public actor is followed, a private one is
    /// asked, and the button reflects each.
    @Test("Test Follow Back Follows A Public Actor And Requests A Private One")
    func testFollowBackFollowsAPublicActorAndRequestsAPrivateOne() async {
        let interactor = Interactor()
        interactor.usersById = [
            "public": UserModel(userId: "public"),
            "private": UserModel(userId: "private", isPrivate: true)
        ]
        let presenter = NotificationsPresenter(interactor: interactor, router: Router())
        let fromPublic = follow(from: "public")
        let fromPrivate = follow(from: "private")
        #expect(presenter.followBackState(for: fromPublic) == .follow)

        presenter.onFollowBackPressed(fromPublic)
        presenter.onFollowBackPressed(fromPrivate)
        await TestManagers.eventually { !interactor.followed.isEmpty && !interactor.requested.isEmpty }

        #expect(interactor.followed == ["public"])
        #expect(interactor.requested == ["private"])
        #expect(presenter.followBackState(for: fromPublic) == .following)
        #expect(presenter.followBackState(for: fromPrivate) == .requested)
    }

    @Test("Test Only Follow Rows Offer Follow Back")
    func testOnlyFollowRowsOfferFollowBack() {
        let presenter = NotificationsPresenter(interactor: Interactor(), router: Router())
        let like = ActivityNotificationModel(
            id: "like", type: .like, actorId: "a", actorName: "A", actorImageUrl: nil,
            sessionId: "s", sessionAuthorId: "me", commentText: nil, dateCreated: Date(timeIntervalSince1970: 0), isRead: false
        )

        #expect(presenter.showsFollowBack(for: follow(from: "a")))
        #expect(!presenter.showsFollowBack(for: like))
        #expect(!presenter.showsFollowBack(for: follow(from: "me")))
    }

    /// A swipe-to-delete was `try?`-ed, so a refused delete brought the row back on the next read
    /// with no explanation.
    @Test("Test A Failed Delete Alerts Once")
    func testAFailedDeleteAlertsOnce() async {
        let interactor = Interactor()
        interactor.deleteError = DevToolsTestError.failed
        let router = Router()
        let presenter = NotificationsPresenter(interactor: interactor, router: router)

        presenter.onNotificationDeleted(follow(from: "alice"))

        #expect(await TestManagers.eventually(timeout: .seconds(5)) { !router.alertTitles.isEmpty })
        for _ in 0..<10 { await Task.yield() }
        #expect(router.alertTitles == ["Unable to Delete Notification"])
        #expect(interactor.trackedEventNames == ["NotificationsView_DeleteNotification_Fail"])
    }
}
