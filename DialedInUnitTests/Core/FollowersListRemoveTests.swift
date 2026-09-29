//
//  FollowersListRemoveTests.swift
//  DialedInUnitTests
//
//  Removing a follower from the reader's own followers list: a confirmation first, then the
//  removeFollower call, and the row leaves the list.
//

import Testing
import SwiftUI
@testable import DialedIn

@MainActor
struct FollowersListRemoveTests {

    private final class Interactor: SpyGlobalInteractor, FollowersListInteractor {
        var currentUser: UserModel? = UserModel(userId: "me")
        var sentFollowRequestIds: Set<String> = []
        var removeError: Error?
        private(set) var removed: [String] = []

        func followUser(userId: String) async throws { }
        func unfollowUser(userId: String) async throws { }
        func sendFollowRequest(to user: UserModel) async throws { }
        func cancelFollowRequest(userId: String) async throws { }
        func removeFollower(userId: String) async throws {
            if let removeError { throw removeError }
            removed.append(userId)
        }
    }

    private final class Router: FollowersListRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []

        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
        func showSocialProfileView(delegate: SocialProfileDelegate) { }
    }

    private let followers = [UserModel(userId: "a"), UserModel(userId: "b")]

    @Test("Test Remove Asks First And Removes Nothing Yet")
    func testRemoveAsksFirstAndRemovesNothingYet() {
        let interactor = Interactor()
        let router = Router()
        let presenter = FollowersListPresenter(interactor: interactor, router: router)

        presenter.onRemoveFollowerPressed(user: followers[0])

        #expect(router.alertTitles == ["Remove Follower?"])
        #expect(interactor.removed.isEmpty)
        #expect(presenter.visibleFollowers(followers).count == 2)
    }

    @Test("Test A Confirmed Remove Calls Through And Drops The Row")
    func testAConfirmedRemoveCallsThroughAndDropsTheRow() async {
        let interactor = Interactor()
        let presenter = FollowersListPresenter(interactor: interactor, router: Router())

        await presenter.removeFollower(followers[0])

        #expect(interactor.removed == ["a"])
        #expect(presenter.visibleFollowers(followers).map(\.userId) == ["b"])
        #expect(interactor.trackedEventNames == ["FollowersListView_RemoveFollower"])
    }

    @Test("Test Offline Remove Says You're Offline And Keeps The Row")
    func testOfflineRemoveSaysYoureOfflineAndKeepsTheRow() async {
        let interactor = Interactor()
        interactor.isOffline = true
        let router = Router()
        let presenter = FollowersListPresenter(interactor: interactor, router: router)

        await presenter.removeFollower(followers[0])

        #expect(router.alertTitles == [OfflineError.title])
        #expect(interactor.removed.isEmpty)
        #expect(presenter.visibleFollowers(followers).count == 2)
    }

    @Test("Test A Failed Remove Keeps The Row And Says So")
    func testAFailedRemoveKeepsTheRowAndSaysSo() async {
        let interactor = Interactor()
        interactor.removeError = DashboardTestError.failed
        let router = Router()
        let presenter = FollowersListPresenter(interactor: interactor, router: router)

        await presenter.removeFollower(followers[0])

        #expect(router.alertTitles == ["Unable to remove follower"])
        #expect(presenter.visibleFollowers(followers).count == 2)
    }

    /// The manager hands the call to the query service, which fronts the Cloud Function.
    @Test("Test The Manager Sends The Removal To The Service")
    func testTheManagerSendsTheRemovalToTheService() async throws {
        let queries = MockUserQueryService()
        let manager = UserManager(
            queryService: queries,
            userSyncEngine: TestManagers.documentEngine(UserModel(userId: "me"), key: "user"),
            followingUsersSyncEngine: TestManagers.collectionEngine([UserModel](), key: "following-users"),
            privateSettingsSyncEngine: TestManagers.documentEngine(PrivateUserSettings?.none, key: "private-user-settings")
        )

        try await manager.removeFollower(userId: "a")

        #expect(queries.removedFollowerIds == ["a"])
    }
}
