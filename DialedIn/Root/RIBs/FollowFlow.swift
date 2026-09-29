//
//  FollowFlow.swift
//  DialedIn
//

import SwiftUI

/// What the follow button offers for one person, from the reader's side.
enum FollowState: Equatable {
    /// Not following; tapping follows a public profile and requests a private one.
    case follow
    case following
    /// A request to a private profile is waiting on its owner; tapping cancels it.
    case requested
}

@MainActor
protocol FollowInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var sentFollowRequestIds: Set<String> { get }
    func followUser(userId: String) async throws
    func unfollowUser(userId: String) async throws
    func sendFollowRequest(to user: UserModel) async throws
    func cancelFollowRequest(userId: String) async throws
}

extension FollowInteractor {
    /// Following wins over a request, so a request the owner accepted reads as following the moment
    /// the Cloud Function's write reaches the reader's document.
    func followState(for userId: String) -> FollowState {
        if currentUser?.followingIds?.contains(userId) ?? false { return .following }
        if sentFollowRequestIds.contains(userId) { return .requested }
        return .follow
    }

    func followState(for user: UserModel) -> FollowState {
        followState(for: user.userId)
    }
}

extension CoreInteractor: FollowInteractor { }

/// The one follow button behaviour — follow, request, unfollow, cancel, and say when it failed —
/// shared by the profile, search, followers, suggestions and notifications so they do not drift.
@MainActor
final class FollowFlow {
    private let interactor: FollowInteractor
    private let router: GlobalRouter

    init(interactor: FollowInteractor, router: GlobalRouter) {
        self.interactor = interactor
        self.router = router
    }

    func state(for user: UserModel) -> FollowState {
        interactor.followState(for: user)
    }

    /// Does whatever the button currently offers. `user` must carry an up-to-date `isPrivate`, since
    /// that decides between following and requesting.
    func onButtonPressed(user: UserModel) {
        let state = state(for: user)
        Task {
            do {
                switch state {
                case .follow where user.isPrivate == true:
                    try await interactor.sendFollowRequest(to: user)
                case .follow:
                    try await interactor.followUser(userId: user.userId)
                case .following:
                    try await interactor.unfollowUser(userId: user.userId)
                case .requested:
                    try await interactor.cancelFollowRequest(userId: user.userId)
                }
            } catch {
                router.showSimpleAlert(title: Self.failureTitle(for: state), subtitle: String(localized: "Please try again."))
            }
        }
    }

    private static func failureTitle(for state: FollowState) -> String {
        switch state {
        case .follow: String(localized: "Unable to follow user")
        case .following: String(localized: "Unable to unfollow user")
        case .requested: String(localized: "Unable to cancel request")
        }
    }
}
