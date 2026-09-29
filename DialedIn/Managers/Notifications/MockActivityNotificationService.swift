//
//  MockActivityNotificationService.swift
//  DialedIn
//
//  Created by Andrew Coyle on 08/03/2026.
//

import Foundation

@MainActor
class MockActivityNotificationService: ActivityNotificationService {

    private var notifications: [ActivityNotificationModel] = ActivityNotificationModel.mocks

    func fetchNotifications(userId: String) async throws -> [ActivityNotificationModel] {
        notifications
    }

    func addNotification(_ notification: ActivityNotificationModel, userId: String) async throws {
        notifications.removeAll { $0.id == notification.id }
        notifications.insert(notification, at: 0)
    }

    func deleteNotification(id: String, userId: String) async throws {
        notifications.removeAll { $0.id == id }
    }

    func markAllRead(userId: String) async throws {
        notifications = notifications.map {
            var notification = $0
            notification.isRead = true
            return notification
        }
    }

    func startListening(userId: String, onNew: @escaping (ActivityNotificationModel) -> Void) { }

    func stopListening() { }

    // MARK: - GroupedNotifications

    func fetchNotifications(userId: String, before: Date) async throws -> [ActivityNotificationModel] {
        Array(notifications.filter { $0.dateCreated < before }
            .sorted { $0.dateCreated > $1.dateCreated }
            .prefix(ActivityNotificationManager.pageSize))
    }

    func markRead(ids: [String], userId: String) async throws {
        notifications = notifications.map {
            var notification = $0
            if ids.contains(notification.id) { notification.isRead = true }
            return notification
        }
    }
}
