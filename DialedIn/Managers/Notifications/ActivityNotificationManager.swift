//
//  ActivityNotificationManager.swift
//  DialedIn
//
//  Created by Andrew Coyle on 08/03/2026.
//

import Foundation

@Observable
@MainActor
class ActivityNotificationManager {

    private let service: ActivityNotificationService
    private(set) var notifications: [ActivityNotificationModel] = []
    var pendingBanner: ActivityNotificationModel?

    init(service: ActivityNotificationService) {
        self.service = service
    }

    func fetchNotifications(userId: String) async throws {
        notifications = try await service.fetchNotifications(userId: userId)
        hasMore = notifications.count >= Self.pageSize
    }

    func addNotification(_ notification: ActivityNotificationModel, userId: String) async throws {
        try await service.addNotification(notification, userId: userId)
    }

    func deleteNotification(id: String, userId: String) async throws {
        try await service.deleteNotification(id: id, userId: userId)
        notifications.removeAll { $0.id == id }
    }

    func markAllRead(userId: String) async throws {
        try await service.markAllRead(userId: userId)
        notifications = notifications.map {
            var notification = $0
            notification.isRead = true
            return notification
        }
    }

    func startListening(userId: String) {
        service.startListening(userId: userId) { [weak self] notification in
            guard let self else { return }
            notifications.insert(notification, at: 0)
            pendingBanner = notification
            NotificationCenter.default.post(name: .newActivityNotification, object: notification)
            let id = notification.id
            Task {
                try? await Task.sleep(for: .seconds(4))
                if pendingBanner?.id == id { pendingBanner = nil }
            }
        }
    }

    func stopListening() {
        service.stopListening()
    }

    // MARK: - GroupedNotifications

    static let pageSize = 50
    /// Whether the last page came back full, so another may exist.
    private(set) var hasMore = false

    /// Appends the page older than the oldest notification held.
    func fetchMore(userId: String) async throws {
        guard let oldest = notifications.map(\.dateCreated).min() else { return }
        let page = try await service.fetchNotifications(userId: userId, before: oldest)
        let held = Set(notifications.map(\.id))
        notifications.append(contentsOf: page.filter { !held.contains($0.id) })
        hasMore = page.count >= Self.pageSize
    }

    func markRead(ids: [String], userId: String) async throws {
        guard !ids.isEmpty else { return }
        try await service.markRead(ids: ids, userId: userId)
        notifications = notifications.map {
            var notification = $0
            if ids.contains(notification.id) { notification.isRead = true }
            return notification
        }
    }
}

extension CoreInteractor {
    /// Nothing a blocked account did reaches the reader — not the list, not the tab badge.
    var activityNotifications: [ActivityNotificationModel] {
        let reader = userManager.currentUser
        return activityNotificationManager.notifications.filter { !(reader?.hasBlocked($0.actorId) ?? false) }
    }

    func fetchActivityNotifications() async throws {
        guard let userId else { return }
        try await activityNotificationManager.fetchNotifications(userId: userId)
    }

    func markActivityNotificationsRead() async throws {
        guard let userId else { return }
        try await activityNotificationManager.markAllRead(userId: userId)
    }

    func deleteActivityNotification(id: String) async throws {
        guard let userId else { return }
        try await activityNotificationManager.deleteNotification(id: id, userId: userId)
    }

}
