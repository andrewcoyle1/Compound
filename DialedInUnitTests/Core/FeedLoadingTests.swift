//
//  FeedLoadingTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

/// The Dashboard feed shows a spinner, not "No Activity Yet", until the following feed has
/// answered once — an empty feed before then only means it has not loaded.
@MainActor
struct FeedLoadingTests {

    private func presenter(_ interactor: DashboardFeedPresenterTests.Interactor) -> DashboardPresenter {
        DashboardPresenter(interactor: interactor, router: DashboardFeedPresenterTests.Router())
    }

    @Test("An empty feed is loading until the following feed has answered")
    func emptyFeedIsLoadingUntilAnswered() {
        let interactor = DashboardFeedPresenterTests.Interactor()
        interactor.hasLoadedFollowingSessions = false
        let presenter = presenter(interactor)
        #expect(presenter.isFeedLoading)

        interactor.hasLoadedFollowingSessions = true
        #expect(!presenter.isFeedLoading)
    }

    @Test("Sessions already in hand are shown rather than a spinner")
    func sessionsInHandAreNotLoading() {
        let interactor = DashboardFeedPresenterTests.Interactor()
        interactor.hasLoadedFollowingSessions = false
        interactor.workoutSessions = [DashboardFixture.session(id: "mine", on: DashboardFixture.date(day: 2))]
        #expect(!presenter(interactor).isFeedLoading)
    }

    @Test("The manager marks the following feed loaded after sign-in and forgets it on sign-out")
    func managerTracksFirstLoad() async {
        let following = [DashboardFixture.session(id: "theirs", author: "friend", on: DashboardFixture.date(day: 2))]
        let manager = TestManagers.workoutSessionManager(following: following)
        #expect(!manager.hasLoadedFollowingSessions)

        await manager.signIn(userId: "me", followingIds: ["friend"])
        #expect(manager.hasLoadedFollowingSessions)
        #expect(manager.followingWorkoutSessions.map(\.id) == ["theirs"])

        manager.signOut()
        #expect(!manager.hasLoadedFollowingSessions)
    }

    @Test("Following nobody counts as loaded at once")
    func followingNobodyIsLoaded() async {
        let manager = TestManagers.workoutSessionManager()
        await manager.signIn(userId: "me", followingIds: [])
        #expect(manager.hasLoadedFollowingSessions)
    }
}
