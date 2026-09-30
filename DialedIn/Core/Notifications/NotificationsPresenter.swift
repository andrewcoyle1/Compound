//
//  NotificationsPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 26/10/2025.
//

import SwiftUI

@Observable
@MainActor
class NotificationsPresenter {
    private let interactor: NotificationsInteractor
    private let router: NotificationsRouter
    private let followFlow: FollowFlow

    /// Requests to follow the reader's private profile, answered from the top of the screen.
    var incomingFollowRequests: [FollowRequestModel] {
        interactor.incomingFollowRequests
    }

    var activityNotifications: [ActivityNotificationModel] {
        interactor.activityNotifications
    }

    /// True only until the first load lands, so pull-to-refresh does not tear the list down and
    /// lose the scroll position: the refresh control is its own indicator for that case.
    private(set) var isLoading: Bool = true
    private var hasLoadedOnce = false
    private(set) var loadFailed = false

    init(
        interactor: NotificationsInteractor,
        router: NotificationsRouter
    ) {
        self.interactor = interactor
        self.router = router
        self.followFlow = FollowFlow(interactor: interactor, router: router)
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func loadNotifications() async {
        isLoading = !hasLoadedOnce
        do {
            try await interactor.fetchActivityNotifications()
            loadFailed = false
        } catch {
            // Only surfaced as an empty-inbox misread before this: a real failure and "no
            // notifications yet" read identically to the person looking at the screen.
            loadFailed = true
        }
        // Silent: a stale unread badge is the right fallback for this one, not an alert.
        try? await interactor.markActivityNotificationsRead()
        interactor.clearAllDeliveredNotifications()
        isLoading = false
        hasLoadedOnce = true
    }

    func onRetryLoadPressed() {
        Task { await loadNotifications() }
    }

    /// Pull-to-refresh re-reads the follow requests too, in case the listener has dropped. The
    /// refresh control is the indicator here, so this never sets `isLoading` and tears the list down.
    func onPullToRefresh() async {
        // Silent: the live listener still owns this list; the refresh is only a backstop.
        try? await interactor.fetchIncomingFollowRequests()
        await loadNotifications()
    }

    func onNotificationDeleted(_ notification: ActivityNotificationModel) {
        Task {
            do {
                try await interactor.deleteActivityNotification(id: notification.id)
            } catch {
                interactor.trackEvent(event: Event.deleteNotificationFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Delete Notification"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    // MARK: Follow back and follow requests

    /// Only a follow row offers a follow back, and never for the reader themselves.
    func showsFollowBack(for notification: ActivityNotificationModel) -> Bool {
        notification.type == .follow && notification.actorId != interactor.currentUser?.userId
    }

    func followBackState(for notification: ActivityNotificationModel) -> FollowState {
        interactor.followState(for: notification.actorId)
    }

    /// The notification does not carry the actor's privacy, so the profile is read when the button
    /// is tapped: whether it follows or requests depends on the account as it is now, not as it was
    /// when they followed.
    func onFollowBackPressed(_ notification: ActivityNotificationModel) {
        interactor.trackEvent(event: Event.followBackPressed)
        Task {
            do {
                let actor = try await interactor.getUser(userId: notification.actorId)
                followFlow.onButtonPressed(user: actor)
            } catch {
                router.showSimpleAlert(title: String(localized: "Unable to Follow User"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    func onAcceptRequestPressed(_ request: FollowRequestModel) {
        respond(to: request, accept: true)
    }

    func onDeclineRequestPressed(_ request: FollowRequestModel) {
        respond(to: request, accept: false)
    }

    private func respond(to request: FollowRequestModel, accept: Bool) {
        interactor.trackEvent(event: Event.followRequestAnswered(accept: accept))
        Task {
            do {
                try await interactor.respondToFollowRequest(requesterId: request.requesterId, accept: accept)
                if accept { interactor.playHaptic(option: .success) }
            } catch {
                interactor.playHaptic(option: .error)
                router.showSimpleAlert(title: String(localized: "Unable to Answer Request"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    /// The row being opened, so its own button can show a spinner instead of the whole screen going
    /// behind a loading modal for what is just a read.
    private(set) var loadingNotificationId: String?

    /// A like, comment or mention opens the session it is about — a comment or mention with its
    /// thread on top — a follow, an accepted request or a nudge opens the other person's profile, and
    /// a share opens the shared template or mesocycle, and a finished challenge opens its standings.
    func onNotificationPressed(_ notification: ActivityNotificationModel) {
        interactor.trackEvent(event: Event.notificationPressed(type: notification.type))
        loadingNotificationId = notification.id
        Task {
            defer { loadingNotificationId = nil }
            do {
                switch notification.type {
                case .follow, .followAccepted, .nudge:
                    let user = try await interactor.getUser(userId: notification.actorId)
                    router.showSocialProfileView(delegate: SocialProfileDelegate(user: user))
                case .like, .comment, .mention:
                    // Browsing pushes: everything opened from inside the Notifications sheet
                    // pushes within it rather than sheeting on top.
                    let session = try await interactor.fetchWorkoutSession(id: notification.sessionId, authorId: notification.sessionAuthorId)
                    let delegate = WorkoutSessionDetailDelegate(workoutSession: session)
                    if notification.type == .like {
                        router.showWorkoutSessionDetailView(delegate: delegate)
                    } else {
                        router.showWorkoutSessionThreadPushed(delegate: delegate)
                    }
                case .share:
                    let share = try await interactor.fetchShare(id: notification.shareId ?? "")
                    router.showSharedItemView(delegate: SharedItemDelegate(share: share, senderName: notification.actorName, isPushed: true))
                case .challengeComplete:
                    let challenge = try await interactor.fetchChallenge(id: notification.challengeId ?? "")
                    router.showChallengeDetailView(delegate: ChallengeDetailDelegate(challenge: challenge))
                }
            } catch {
                router.showSimpleAlert(title: String(localized: "Unable to Open"), subtitle: String(localized: "It may have been deleted. Please try again."))
            }
        }
    }
    
    func onNotificationSettingsPressed() {
        router.showNotificationSettingsView(delegate: NotificationSettingsDelegate())
    }
}

extension NotificationsPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case notificationPressed(type: ActivityNotificationModel.ActivityType)
        case followBackPressed
        case followRequestAnswered(accept: Bool)
        case deleteNotificationFail(error: Error)

        var eventName: String {
            switch self {
            case .deleteNotificationFail: return "NotificationsView_DeleteNotification_Fail"
            case .onAppear:     return "NotificationsView_Appear"
            case .onDisappear:  return "NotificationsView_Disappear"
            case .notificationPressed: return "NotificationsView_Notification_Pressed"
            case .followBackPressed: return "NotificationsView_FollowBack_Pressed"
            case .followRequestAnswered: return "NotificationsView_FollowRequest_Answered"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .deleteNotificationFail(error: let error): return error.eventParameters
            case .notificationPressed(let type):
                return ["type": type.rawValue]
            case .followRequestAnswered(let accept):
                return ["accept": accept]
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .deleteNotificationFail: return .severe
            default:
                return .analytic
                
            }
        }
    }
}

// MARK: - GroupedNotifications

extension NotificationsPresenter {
    var notificationGroups: [NotificationGroup] {
        NotificationGrouping.group(activityNotifications)
    }

    var canLoadMore: Bool {
        interactor.canLoadMoreActivityNotifications
    }

    /// Marks every member read and opens what the group is about. Members share a type and a
    /// session, so the newest one stands for all of them.
    func onGroupPressed(_ group: NotificationGroup) {
        let unreadIds = group.unreadIds
        if !unreadIds.isEmpty {
            // Silent: a row left looking unread is the fallback, not an alert over the tap-through.
            Task { try? await interactor.markActivityNotificationsRead(ids: unreadIds) }
        }
        onNotificationPressed(group.newest)
    }

    /// Swiping a group away removes every notification in it.
    func onGroupDeleted(_ group: NotificationGroup) {
        group.members.forEach(onNotificationDeleted)
    }

    func onLoadMorePressed() {
        interactor.trackEvent(event: GroupedNotificationsEvent.loadMore)
        Task {
            do {
                try await interactor.fetchMoreActivityNotifications()
            } catch {
                router.showAlert(title: String(localized: "Unable to Load More"), error: error)
            }
        }
    }

    enum GroupedNotificationsEvent: LoggableEvent {
        case loadMore

        var eventName: String { "NotificationsView_LoadMore_Pressed" }
        var parameters: [String: Any]? { nil }
        var type: LogType { .analytic }
    }
}
