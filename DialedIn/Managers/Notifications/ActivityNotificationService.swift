//
//  ActivityNotificationService.swift
//  DialedIn
//
//  Created by Andrew Coyle on 08/03/2026.
//

import Foundation

@MainActor
protocol ActivityNotificationService: AnyObject {
    func fetchNotifications(userId: String) async throws -> [ActivityNotificationModel]
    func addNotification(_ notification: ActivityNotificationModel, userId: String) async throws
    func deleteNotification(id: String, userId: String) async throws
    func markAllRead(userId: String) async throws
    func startListening(userId: String, onNew: @escaping (ActivityNotificationModel) -> Void)
    func stopListening()
    // MARK: - GroupedNotifications
    /// The next page: up to `ActivityNotificationManager.pageSize` notifications older than `before`, newest first.
    func fetchNotifications(userId: String, before: Date) async throws -> [ActivityNotificationModel]
    func markRead(ids: [String], userId: String) async throws
}
