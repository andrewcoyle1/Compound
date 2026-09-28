//
//  NotificationsView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 02/10/2025.
//

import SwiftUI
import UserNotifications

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
        .onFirstTask {
            await presenter.checkPermissions()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onDismissPressed()
                }
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
            // Push permission governs only the push switches. The activity list is in-app and was
            // hidden behind the prompt, so a simulator (or a user) that never granted push saw none.
            switch presenter.authorizationStatus {
            case .authorized:
                socialPushSection
            case .notDetermined:
                notDeterminedContent
            case .denied, .provisional, .ephemeral:
                deniedContent
            default:
                EmptyView()
            }
            if presenter.activityNotifications.isEmpty {
                emptyStateContent
            } else {
                groupedNotificationsList
            }
        }
    }

    private var socialPushSection: some View {
        Section {
            Toggle("Likes", isOn: $presenter.isLikesPushEnabled)
            Toggle("Comments", isOn: $presenter.isCommentsPushEnabled)
            Toggle("Mentions", isOn: $presenter.isMentionsPushEnabled)
            Toggle("New followers", isOn: $presenter.isFollowsPushEnabled)
            Toggle("Nudges", isOn: $presenter.isNudgesPushEnabled)
            Toggle("Shares", isOn: $presenter.isSharesPushEnabled)
            Toggle("Challenges", isOn: $presenter.isChallengesPushEnabled)
            scheduledPushRows
        } header: {
            Text("Social")
        } footer: {
            Text("Get a push when someone in your circle interacts with you, even when DialedIn is closed.")
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
                }
                .controlSize(.small)
            }
        } header: {
            Text("Follow Requests")
        }
    }

    @ViewBuilder
    private func followRequestButtons(_ request: FollowRequestModel) -> some View {
        Button("Accept") {
            presenter.onAcceptRequestPressed(request)
        }
        .buttonStyle(.glassProminent)
        // The label is drawn on the accent, so it needs onAccent, not the accent's own colour.
        .foregroundStyle(.onAccent)

        Button("Decline") {
            presenter.onDeclineRequestPressed(request)
        }
        .buttonStyle(.glass)
    }

    private func activityNotificationTitle(_ notification: ActivityNotificationModel) -> String {
        switch notification.type {
        case .like:
            return "\(notification.actorName) liked your workout"
        case .comment:
            let preview = notification.commentText.map { ": \"\($0.prefix(60))\"" } ?? ""
            return "\(notification.actorName) commented\(preview)"
        case .follow:
            return "\(notification.actorName) started following you"
        case .nudge:
            return "\(notification.actorName) nudged you to train"
        case .mention:
            let preview = notification.commentText.map { ": \"\($0.prefix(60))\"" } ?? ""
            return "\(notification.actorName) mentioned you\(preview)"
        case .followAccepted:
            return "\(notification.actorName) accepted your follow request"
        case .share:
            return "\(notification.actorName) shared \(notification.commentText ?? "a workout")"
        case .challengeComplete:
            return "You finished \(notification.commentText ?? "a challenge")"
        }
    }

    private var emptyStateContent: some View {
        ContentUnavailableView(
            "No Notifications",
            systemImage: "bell.slash",
            description: Text("You don't have any notifications yet. When you receive notifications, they'll appear here.")
        )
        .padding(.vertical, Spacing.xxl)
    }
    
    private var notDeterminedContent: some View {
        ContentUnavailableView {
            VStack {
                Image(systemName: "bell.badge")
                    .iconSize(.large)
                
                Text("Enable Notifications")
            }
        } description: {
            Text("Stay informed about workouts, nutrition tracking, and important updates. Enable notifications to never miss a beat.")
        } actions: {
            Button {
                presenter.onRequestNotificationsPressed()
            } label: {
                Text("Enable Notifications")
                    .padding(Spacing.s)
            }
            .buttonStyle(.glassProminent)
            // The label is drawn on the accent, so it needs onAccent, not the accent's own colour.
            .foregroundStyle(.onAccent)
        }
        .padding(.vertical)
        .background(in: .containerRelative)
        .removeListRowFormatting()
    }
    
    private var deniedContent: some View {
        ContentUnavailableView {
            VStack {
                Image(systemName: "bell.slash.fill")
                    .iconSize(.large)
                
                Text("Notifications Disabled")
            }
        } description: {
            Text("Notifications are currently disabled. To receive updates, please enable notifications in Settings.")
        } actions: {
            Button {
                presenter.openSettings()
            } label: {
                Text("Open Settings")
                    .padding(Spacing.s)
            }
            .buttonStyle(.glass)
        }
        .padding(.vertical)
        .background(in: .containerRelative)
        .removeListRowFormatting()
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

// MARK: - ScheduledPush

extension NotificationsView {
    @ViewBuilder
    var scheduledPushRows: some View {
        Toggle("Streak reminder", isOn: $presenter.isStreakReminderEnabled)
        if presenter.isStreakReminderEnabled {
            Picker("Remind me at", selection: $presenter.streakReminderHour) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now, format: .dateTime.hour())
                        .tag(hour)
                }
            }
        }
        Toggle("Weekly digest", isOn: $presenter.isWeeklyDigestEnabled)
    }
}

// MARK: - GroupedNotifications

extension NotificationsView {
    @ViewBuilder
    var groupedNotificationsList: some View {
        ForEach(presenter.notificationGroups) { group in
            groupedNotificationRow(group)
                .swipeActions {
                    Button(role: .destructive) {
                        presenter.onGroupDeleted(group)
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
                    stackedAvatars(group.avatarUrls)

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
