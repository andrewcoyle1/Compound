//
//  NotificationGrouping.swift
//  DialedIn
//
//  Collapses activity about the same session into one row: "Alice and 3 others liked your workout".
//

import Foundation

/// One row of the notifications list: a single notification, or several of the same type about
/// the same session, newest first.
struct NotificationGroup: Identifiable {
    let members: [ActivityNotificationModel]

    var id: String { newest.id }
    // Safe: groups come only from NotificationGrouping.group, which never builds an empty one.
    var newest: ActivityNotificationModel { members[0] }
    var type: ActivityNotificationModel.ActivityType { newest.type }
    /// A group is unread while any member is.
    var isRead: Bool { members.allSatisfy { $0.isRead } }
    var unreadIds: [String] { members.filter { !$0.isRead }.map(\.id) }

    /// Each actor once, most recent first, so a repeat commenter is one person.
    var actors: [ActivityNotificationModel] {
        var seen = Set<String>()
        return members.filter { seen.insert($0.actorId).inserted }
    }

    /// "Alice", "Alice and Bob", "Alice and 3 others".
    var actorSummary: String {
        let actors = actors
        switch actors.count {
        case 0, 1: return newest.actorName
        case 2: return String(localized: "\(String(describing: actors[0].actorName)) and \(String(describing: actors[1].actorName))")
        default: return String(localized: "\(String(describing: actors[0].actorName)) and \(String(describing: actors.count - 1)) others")
        }
    }

    /// The row title once several notifications share it; nil for a single one, which keeps its own.
    var groupedTitle: String? {
        guard members.count > 1 else { return nil }
        switch type {
        case .comment: return String(localized: "\(String(describing: actorSummary)) commented on your workout")
        case .mention: return String(localized: "\(String(describing: actorSummary)) mentioned you")
        default: return String(localized: "\(String(describing: actorSummary)) liked your workout")
        }
    }

    /// Up to three avatars for the stack, most recent actor first.
    var avatarUrls: [String?] { actors.prefix(3).map(\.actorImageUrl) }
}

enum NotificationGrouping {
    /// A notification joins a group only within this long of the group's newest member.
    static let window: TimeInterval = 24 * 60 * 60

    /// Only session activity groups. Follows, nudges, accepted requests and shares are about a
    /// person or an item, and each stays a row of its own.
    static func isGroupable(_ notification: ActivityNotificationModel) -> Bool {
        switch notification.type {
        case .like, .comment, .mention: return !notification.sessionId.isEmpty
        case .follow, .nudge, .followAccepted, .share, .challengeComplete: return false
        }
    }

    /// Groups ordered by their newest member. Same type and same session within `window` of the
    /// group's newest member collapse together.
    static func group(_ notifications: [ActivityNotificationModel]) -> [NotificationGroup] {
        var groups: [[ActivityNotificationModel]] = []
        // Newest-first iteration means the last group opened for a key has the oldest anchor, so
        // if the notification misses its window it misses every earlier group's too.
        var openGroup: [String: Int] = [:]
        for notification in notifications.sorted(by: { $0.dateCreated > $1.dateCreated }) {
            guard isGroupable(notification) else {
                groups.append([notification])
                continue
            }
            let key = "\(notification.type.rawValue)|\(notification.sessionId)"
            if let index = openGroup[key],
               // Safe: every group is opened with its first notification.
               groups[index][0].dateCreated.timeIntervalSince(notification.dateCreated) <= window {
                groups[index].append(notification)
            } else {
                openGroup[key] = groups.count
                groups.append([notification])
            }
        }
        return groups.map(NotificationGroup.init)
    }

    /// The badge: one per unread row, not per notification.
    static func unreadGroupCount(_ notifications: [ActivityNotificationModel]) -> Int {
        group(notifications).filter { !$0.isRead }.count
    }
}
