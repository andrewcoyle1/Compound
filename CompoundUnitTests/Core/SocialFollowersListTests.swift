//
//  SocialFollowersListTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

// MARK: - Followers list

/// The people and the title travel in the delegate; the presenter only answers who the reader
/// already follows and forwards the button presses.
@MainActor
struct SocialFollowersListTests {

    private final class Interactor: SpyGlobalInteractor, FollowersListInteractor {
        var currentUser: UserModel? = UserModel(userId: "me", followingIds: ["a"])
        var followError: Error?
        private(set) var followed: [String] = []
        private(set) var unfollowed: [String] = []
        var sentFollowRequestIds: Set<String> = ["pending"]
        private(set) var requested: [String] = []
        private(set) var cancelled: [String] = []

        func sendFollowRequest(to user: UserModel) async throws { requested.append(user.userId) }
        func cancelFollowRequest(userId: String) async throws { cancelled.append(userId) }

        func followUser(userId: String) async throws {
            if let followError { throw followError }
            followed.append(userId)
        }
        func unfollowUser(userId: String) async throws {
            if let followError { throw followError }
            unfollowed.append(userId)
        }
        func removeFollower(userId: String) async throws { }
    }

    private final class Router: FollowersListRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []
        private(set) var profileUserIds: [String] = []

        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
            alertTitles.append(title)
        }
        func showSimpleAlert(title: String, subtitle: String?) {
            alertTitles.append(title)
        }
        func showSocialProfileView(delegate: SocialProfileDelegate) {
            profileUserIds.append(delegate.user.userId)
        }
    }

    @Test("Test The Followers List Defaults To The Followers Title")
    func testTheFollowersListDefaultsToTheFollowersTitle() {
        let delegate = FollowersListDelegate(followers: [DashboardFixture.user("a")])

        #expect(delegate.title == "Followers")
        #expect(delegate.followers.map(\.userId) == ["a"])
    }

    /// Each row's button reads the reader's list, and the reader's own row has none.
    @Test("Test Rows Know Who The Reader Follows And Skip The Reader")
    func testRowsKnowWhoTheReaderFollowsAndSkipTheReader() {
        let presenter = FollowersListPresenter(interactor: Interactor(), router: Router())

        #expect(presenter.followState(for: DashboardFixture.user("a")) == .following)
        #expect(presenter.followState(for: DashboardFixture.user("b")) == .follow)
        #expect(presenter.followState(for: DashboardFixture.user("pending")) == .requested)
        #expect(presenter.showsFollowButton(for: DashboardFixture.user("b")))
        #expect(!presenter.showsFollowButton(for: DashboardFixture.user("me")))
    }

    @Test("Test Each Button State Reaches The Interactor And A Row Opens The Profile")
    func testEachButtonStateReachesTheInteractorAndARowOpensTheProfile() async {
        let interactor = Interactor()
        let router = Router()
        let presenter = FollowersListPresenter(interactor: interactor, router: router)

        presenter.onFollowButtonPressed(user: DashboardFixture.user("b"))
        presenter.onFollowButtonPressed(user: DashboardFixture.user("a"))
        presenter.onFollowButtonPressed(user: UserModel(userId: "private", isPrivate: true))
        presenter.onFollowButtonPressed(user: DashboardFixture.user("pending"))
        presenter.onUserPressed(user: DashboardFixture.user("b"))
        await TestManagers.eventually { !interactor.unfollowed.isEmpty && !interactor.cancelled.isEmpty && !interactor.requested.isEmpty }

        #expect(interactor.followed == ["b"])
        #expect(interactor.unfollowed == ["a"])
        #expect(interactor.requested == ["private"])
        #expect(interactor.cancelled == ["pending"])
        #expect(router.profileUserIds == ["b"])
    }

    @Test("Test A Failed Follow From The List Shows An Alert")
    func testAFailedFollowFromTheListShowsAnAlert() async {
        let interactor = Interactor()
        interactor.followError = DashboardTestError.failed
        let router = Router()
        let presenter = FollowersListPresenter(interactor: interactor, router: router)

        presenter.onFollowButtonPressed(user: DashboardFixture.user("b"))
        await TestManagers.eventually { !router.alertTitles.isEmpty }

        #expect(router.alertTitles == ["Unable to follow user"])
    }
}
