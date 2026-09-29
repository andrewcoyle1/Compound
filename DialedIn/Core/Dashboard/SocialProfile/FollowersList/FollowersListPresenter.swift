//
//  FollowersListPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 02/03/2026.
//

import SwiftUI

@Observable
@MainActor
class FollowersListPresenter {
    private let interactor: FollowersListInteractor
    private let router: FollowersListRouter
    private let followFlow: FollowFlow

    init(interactor: FollowersListInteractor, router: FollowersListRouter) {
        self.interactor = interactor
        self.router = router
        self.followFlow = FollowFlow(interactor: interactor, router: router)
    }

    /// The reader's own row carries no follow button.
    func showsFollowButton(for user: UserModel) -> Bool {
        user.userId != interactor.currentUser?.userId
    }

    func followState(for user: UserModel) -> FollowState {
        followFlow.state(for: user)
    }

    func onFollowButtonPressed(user: UserModel) {
        followFlow.onButtonPressed(user: user)
    }

    func onUserPressed(user: UserModel) {
        router.showSocialProfileView(delegate: SocialProfileDelegate(user: user))
    }

    // MARK: Removing a follower

    /// Followers removed on this screen, dropped from the list at once since the delegate's copy
    /// does not change.
    private(set) var removedFollowerIds: Set<String> = []

    func visibleFollowers(_ followers: [UserModel]) -> [UserModel] {
        followers.filter { !removedFollowerIds.contains($0.userId) }
    }

    func onRemoveFollowerPressed(user: UserModel) {
        let name = user.fullNameCalculated ?? "this person"
        router.showAlert(
            title: String(localized: "Remove Follower?"),
            subtitle: String(localized: "\(name) won't be told they were removed."),
            buttons: {
                AnyView(
                    Group {
                        Button("Cancel", role: .cancel) { }
                        Button("Remove", role: .destructive) {
                            Task { await self.removeFollower(user) }
                        }
                    }
                )
            }
        )
    }

    func removeFollower(_ user: UserModel) async {
        guard interactor.ensureOnline(or: router) else { return }
        interactor.trackEvent(eventName: "FollowersListView_RemoveFollower", parameters: nil, type: .analytic)
        do {
            try await interactor.removeFollower(userId: user.userId)
            removedFollowerIds.insert(user.userId)
        } catch {
            router.showSimpleAlert(title: String(localized: "Unable to remove follower"), subtitle: String(localized: "Please try again."))
        }
    }
}
