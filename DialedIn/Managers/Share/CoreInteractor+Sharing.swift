//
//  CoreInteractor+Sharing.swift
//  DialedIn
//

import Foundation

extension CoreInteractor {

    /// One `shares` document and one `.share` notification per recipient. The notification is
    /// keyed by the share, so a retry overwrites rather than stacks.
    func sendShare(_ payload: ShareModel.Payload, to userIds: [String]) async throws {
        guard let actor = userManager.currentUser else { throw AppError("Not signed in.") }
        for recipientId in userIds {
            let share = ShareModel(fromUserId: actor.userId, toUserId: recipientId, payload: payload)
            try await shareManager.sendShare(share)
            let notification = ActivityNotificationModel(
                id: "share_\(share.id)",
                type: .share,
                actorId: actor.userId,
                actorName: actor.fullNameCalculated ?? "Someone",
                actorImageUrl: actor.submittedProfileImage,
                sessionId: "",
                sessionAuthorId: recipientId,
                commentText: payload.name,
                dateCreated: share.dateCreated,
                isRead: false,
                shareId: share.id
            )
            try await activityNotificationManager.addNotification(notification, userId: recipientId)
        }
    }

    func fetchShare(id: String) async throws -> ShareModel {
        try await shareManager.fetchShare(id: id)
    }

    func updateShareStatus(_ status: ShareModel.Status, id: String) async throws {
        try await shareManager.updateShareStatus(status, id: id)
    }
}
