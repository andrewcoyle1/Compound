//
//  CoreInteractor+GroupedNotifications.swift
//  DialedIn
//

import Foundation

extension CoreInteractor {
    var canLoadMoreActivityNotifications: Bool {
        activityNotificationManager.hasMore
    }

    func fetchMoreActivityNotifications() async throws {
        guard let userId else { return }
        try await activityNotificationManager.fetchMore(userId: userId)
    }

    func markActivityNotificationsRead(ids: [String]) async throws {
        guard let userId else { return }
        try await activityNotificationManager.markRead(ids: ids, userId: userId)
    }
}
