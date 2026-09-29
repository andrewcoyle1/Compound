//
//  NotificationsView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 02/10/2025.
//

import SwiftUI

struct NotificationsView: View {

    @State var presenter: NotificationsPresenter

    var body: some View {
        Group {
            if presenter.isLoading {
                ProgressView()
            } else {
                content
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onDismissPressed()
                }
            }
            // The close button owns the leading edge, so settings sit apart from it on the trailing one.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presenter.onNotificationSettingsPressed()
                } label: {
                    Image(systemName: Symbol.settings)
                }
                .accessibilityLabel("Notification Settings")
            }
        }
        .task {
            await presenter.loadNotifications()
        }
        .refreshable { await presenter.onPullToRefresh() }
    }
    
    @ViewBuilder
    private var content: some View {
        List {
            if !presenter.incomingFollowRequests.isEmpty {
                followRequestsSection
            }
            if presenter.loadFailed {
                loadFailedContent
            } else if presenter.activityNotifications.isEmpty {
                emptyStateContent
            } else {
                groupedNotificationsList
            }
        }
    }

    private var followRequestsSection: some View {
        Section {
            ForEach(presenter.incomingFollowRequests) { request in
                // Buttons move under the name at accessibility sizes, where beside it they
                // wrapped "Accept" a letter per line.
                AdaptiveStack(spacing: Spacing.m) {
                    HStack(spacing: Spacing.m) {
                        UserAvatarView(imageUrl: request.requesterImageUrl, size: ControlSize.thumbnail)

                        // Name and verb on their own lines: on one line the two buttons truncated it.
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(request.requesterName)
                                .font(.rowTitle)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text("Wants to follow you")
                                .font(.rowDetail)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    Spacer(minLength: 0)

                    // Side by side while both fit, one above the other once they do not.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Spacing.m) { followRequestButtons(request) }
                        VStack(alignment: .leading, spacing: Spacing.s) { followRequestButtons(request) }
                    }
                    .lineLimit(1)
                    // Small, so both fit beside the name at the default size; each label's
                    // `tapTarget()` keeps the hit area at 44 pt.
                    .controlSize(.small)
                }
            }
        } header: {
            Text("Follow Requests")
        }
    }

    @ViewBuilder
    private func followRequestButtons(_ request: FollowRequestModel) -> some View {
        Button {
            presenter.onAcceptRequestPressed(request)
        } label: {
            Text("Accept").tapTarget()
        }
        .buttonStyle(.glassProminent)
        // The label is drawn on the accent, so it needs onAccent, not the accent's own colour.
        .foregroundStyle(.onAccent)

        Button {
            presenter.onDeclineRequestPressed(request)
        } label: {
            Text("Decline").tapTarget()
        }
        .buttonStyle(.glass)
    }

    private func activityNotificationTitle(_ notification: ActivityNotificationModel) -> String {
        switch notification.type {
        case .like:
            return String(localized: "\(notification.actorName) liked your workout")
        case .comment:
            return commentOrMentionTitle(notification, mentioned: false)
        case .follow:
            return String(localized: "\(notification.actorName) started following you")
        case .nudge:
            return String(localized: "\(notification.actorName) nudged you to train")
        case .mention:
            return commentOrMentionTitle(notification, mentioned: true)
        case .followAccepted:
            return String(localized: "\(notification.actorName) accepted your follow request")
        case .share:
            return shareTitle(notification)
        case .challengeComplete:
            return challengeCompleteTitle(notification)
        }
    }

    private func commentOrMentionTitle(_ notification: ActivityNotificationModel, mentioned: Bool) -> String {
        guard let preview = notification.commentText?.prefix(60) else {
            return mentioned
                ? String(localized: "\(notification.actorName) mentioned you")
                : String(localized: "\(notification.actorName) commented")
        }
        return mentioned
            ? String(localized: "\(notification.actorName) mentioned you: \"\(preview)\"")
            : String(localized: "\(notification.actorName) commented: \"\(preview)\"")
    }

    private func shareTitle(_ notification: ActivityNotificationModel) -> String {
        guard let commentText = notification.commentText else {
            return String(localized: "\(notification.actorName) shared a workout")
        }
        return String(localized: "\(notification.actorName) shared \(commentText)")
    }

    private func challengeCompleteTitle(_ notification: ActivityNotificationModel) -> String {
        guard let commentText = notification.commentText else {
            return String(localized: "You finished a challenge")
        }
        return String(localized: "You finished \(commentText)")
    }

    private var loadFailedContent: some View {
        ContentUnavailableView {
            Label("Unable to Load Notifications", systemImage: Symbol.warning)
        } description: {
            Text("Check your connection and try again.")
        } actions: {
            Button("Try Again") {
                presenter.onRetryLoadPressed()
            }
        }
        .padding(.vertical, Spacing.xxl)
    }

    private var emptyStateContent: some View {
        ContentUnavailableView(
            "No Notifications",
            systemImage: "bell.slash",
            description: Text("You don't have any notifications yet. When you receive notifications, they'll appear here.")
        )
        .padding(.vertical, Spacing.xxl)
    }
}

extension CoreBuilder {
    func notificationsView(router: AnyRouter) -> some View {
        NotificationsView(
            presenter: NotificationsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
}

extension CoreRouter {
    func showNotificationsView() {
        router.showScreen(.sheet) { router in
            builder.notificationsView(router: router)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.notificationsView(router: router)
    }
    
}

// MARK: - GroupedNotifications

extension NotificationsView {
    @ViewBuilder
    var groupedNotificationsList: some View {
        ForEach(presenter.notificationGroups) { group in
            groupedNotificationRow(group)
                .rowActions {
                    Button(role: .destructive) {
                        presenter.onGroupDeleted(group)
                    } label: {
                        Label("Delete", systemImage: Symbol.delete)
                    }
                }
        }
        if presenter.canLoadMore {
            Button("Load more") {
                presenter.onLoadMorePressed()
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// The text is one button, and so one VoiceOver stop reading the title, the time and whether
    /// it is unread; the follow-back button sits beside it rather than inside it, so it stays a
    /// stop of its own instead of a button nested in a button.
    private func groupedNotificationRow(_ group: NotificationGroup) -> some View {
        AdaptiveStack(spacing: Spacing.m) {
            Button {
                presenter.onGroupPressed(group)
            } label: {
                HStack(spacing: Spacing.m) {
                    if presenter.loadingNotificationId == group.newest.id {
                        ProgressView()
                            .frame(width: Spacing.xxl, height: Spacing.xxl)
                    } else {
                        stackedAvatars(group.avatarUrls)
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(group.groupedTitle ?? activityNotificationTitle(group.newest))
                            .font(.rowTitle)
                            .fontWeight(group.isRead ? .regular : .semibold)
                            .foregroundStyle(group.isRead ? .secondary : .primary)

                        Text(group.newest.dateCreated.formatted(date: .abbreviated, time: .shortened))
                            .font(.label)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(presenter.loadingNotificationId != nil)
            .accessibilityElement(children: .combine)
            // Read and unread differ only by text colour on screen.
            .accessibilityValue(group.isRead ? "" : "Unread")

            if presenter.showsFollowBack(for: group.newest) {
                FollowButton(state: presenter.followBackState(for: group.newest)) {
                    presenter.onFollowBackPressed(group.newest)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    /// Up to three overlapping avatars, the most recent actor on top. Decorative: the title names them.
    private func stackedAvatars(_ urls: [String?]) -> some View {
        HStack(spacing: -Spacing.m) {
            ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                UserAvatarView(imageUrl: url, size: Spacing.xxl)
                    .overlay(Circle().stroke(.surface, lineWidth: 2))
                    .zIndex(Double(urls.count - index))
            }
        }
        .accessibilityHidden(true)
    }
}
