//
//  ActivityNotificationBannerView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 08/03/2026.
//

import SwiftUI

struct ActivityNotificationBannerView: View {

    let notification: ActivityNotificationModel

    private var message: String {
        switch notification.type {
        case .like:
            return String(localized: "\(notification.actorName) liked your workout")
        case .comment:
            if let text = notification.commentText, !text.isEmpty {
                let preview = text.count > 40 ? String(text.prefix(40)) + "…" : text
                return String(localized: "\(notification.actorName) commented: \"\(preview)\"")
            }
            return String(localized: "\(notification.actorName) commented on your workout")
        case .follow:
            return String(localized: "\(notification.actorName) started following you")
        case .nudge:
            return String(localized: "\(notification.actorName) nudged you to train")
        case .mention:
            let text = notification.commentText ?? ""
            let preview = text.count > 40 ? String(text.prefix(40)) + "…" : text
            return String(localized: "\(notification.actorName) mentioned you: \"\(preview)\"")
        case .followAccepted:
            return String(localized: "\(notification.actorName) accepted your follow request")
        case .share:
            return String(localized: "\(notification.actorName) shared \(notification.commentText ?? "a workout") with you")
        case .challengeComplete:
            return String(localized: "You finished \(notification.commentText ?? "a challenge")")
        }
    }

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: Symbol.notifications + ".fill")
                .foregroundStyle(.primary)
                .font(.rowDetail)

            Text(message)
                .font(.rowDetail)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.xl, style: .continuous))
        .padding(.horizontal, Spacing.xl)
        .accessibilityElement(children: .combine)
        // It appears over whatever the person is doing, so VoiceOver has to be told.
        .task(id: notification.id) {
            AccessibilityNotification.Announcement(message).post()
        }
    }
}

#Preview {
    VStack {
        ActivityNotificationBannerView(
            notification: ActivityNotificationModel(
                id: "1",
                type: .like,
                actorId: "a",
                actorName: "Jane Smith",
                actorImageUrl: nil,
                sessionId: "s",
                sessionAuthorId: "u",
                commentText: nil,
                dateCreated: Date(),
                isRead: false
            )
        )
        ActivityNotificationBannerView(
            notification: ActivityNotificationModel(
                id: "2",
                type: .comment,
                actorId: "a",
                actorName: "John Doe",
                actorImageUrl: nil,
                sessionId: "s",
                sessionAuthorId: "u",
                commentText: "Great workout, keep it up!",
                dateCreated: Date(),
                isRead: false
            )
        )
    }
    .padding(.top, Spacing.xxl)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color.gray.opacity(0.2))
}
