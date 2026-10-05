//
//  FollowFlow.swift
//  Compound
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
        let action = Action(state: state, isPrivate: user.isPrivate == true)
        interactor.trackEvent(event: Event.start(action))
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
                interactor.trackEvent(event: Event.success(action))
            } catch {
                interactor.trackEvent(event: Event.fail(action, error: error))
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

    /// What the button did, named for the events.
    enum Action: String {
        case follow = "Follow"
        case requestFollow = "RequestFollow"
        case unfollow = "Unfollow"
        case cancelRequest = "CancelRequest"

        init(state: FollowState, isPrivate: Bool) {
            switch state {
            case .follow: self = isPrivate ? .requestFollow : .follow
            case .following: self = .unfollow
            case .requested: self = .cancelRequest
            }
        }
    }

    enum Event: LoggableEvent {
        case start(Action)
        case success(Action)
        case fail(Action, error: Error)

        var eventName: String {
            switch self {
            case .start(let action):    return "FollowFlow_\(action.rawValue)_Start"
            case .success(let action):  return "FollowFlow_\(action.rawValue)_Success"
            case .fail(let action, _):  return "FollowFlow_\(action.rawValue)_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .fail(_, let error): return error.eventParameters
            default: return nil
            }
        }

        var type: LogType {
            switch self {
            case .fail: return .severe
            default: return .analytic
            }
        }
    }
}
