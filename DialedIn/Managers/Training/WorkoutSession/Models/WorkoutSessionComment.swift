//
//  WorkoutSessionComment.swift
//  DialedIn
//
//  Created by Andrew Coyle on 08/03/2026.
//

import Foundation

struct WorkoutSessionComment: Identifiable, Codable, Equatable {
    let id: String
    let sessionId: String
    let sessionAuthorId: String
    let authorId: String
    let authorName: String?
    let authorImageUrl: String?
    let text: String
    let dateCreated: Date
    var deletedAt: Date?
    /// The comment this one replies to. One level only: a reply to a reply carries the same
    /// parent, so a thread is a comment and its replies, never a tree.
    var parentId: String?
    /// Everyone tagged with an `@FirstName` in the text. Identity lives here rather than in the
    /// text, so two people with the same first name stay distinct.
    var mentionedUserIds: [String] = []
    /// Everyone who has liked the comment. Each reader may add or remove only their own id.
    var likedByUserIds: [String] = []
    /// Set by the `onReportCreated` function once three people have reported this comment.
    var hidden: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case sessionAuthorId = "session_author_id"
        case authorId = "author_id"
        case authorName = "author_name"
        case authorImageUrl = "author_image_url"
        case text
        case dateCreated = "date_created"
        case deletedAt = "deleted_at"
        case parentId = "parent_id"
        case mentionedUserIds = "mentioned_user_ids"
        case likedByUserIds = "liked_by_user_ids"
        case hidden
    }

    /// Whether the thread leaves this comment out for `readerId`: hidden by moderation and not
    /// the reader's own.
    func isHidden(from readerId: String?) -> Bool {
        hidden == true && readerId != authorId
    }

    /// Who hears about this comment. The session's author hears about every one, and a reply also
    /// reaches the author of the comment it answers; anyone mentioned who is not already one of
    /// those gets a mention instead. The writer is told about nothing, and nobody is told twice.
    func activityRecipients(parentAuthorId: String?) -> (commented: Set<String>, mentioned: Set<String>) {
        var commented: Set<String> = [sessionAuthorId]
        if let parentAuthorId { commented.insert(parentAuthorId) }
        commented.remove(authorId)
        let mentioned = Set(mentionedUserIds).subtracting(commented).subtracting([authorId])
        return (commented, mentioned)
    }

    /// The notifications this comment writes, keyed by recipient. The parent comment's author
    /// hears it as a reply, unless they are the session's author, who hears it as a comment on
    /// their workout like every other comment.
    func activityNotifications(parentAuthorId: String?) -> [(userId: String, notification: ActivityNotificationModel)] {
        let recipients = activityRecipients(parentAuthorId: parentAuthorId)
        let commented = recipients.commented.sorted().map { userId in
            var notification = activityNotification(type: .comment)
            notification.isReply = parentId != nil && userId == parentAuthorId && userId != sessionAuthorId
            return (userId, notification)
        }
        let mentioned = recipients.mentioned.sorted().map { ($0, activityNotification(type: .mention)) }
        return commented + mentioned
    }

    private func activityNotification(type: ActivityNotificationModel.ActivityType) -> ActivityNotificationModel {
        ActivityNotificationModel(
            id: "\(type.rawValue)_\(id)",
            type: type,
            actorId: authorId,
            actorName: authorName ?? "Someone",
            actorImageUrl: authorImageUrl,
            sessionId: sessionId,
            sessionAuthorId: sessionAuthorId,
            commentText: text,
            dateCreated: dateCreated,
            isRead: false
        )
    }

    @MainActor
    static var mock: WorkoutSessionComment {
        WorkoutSessionComment(
            id: "comment-1",
            sessionId: "session-1",
            sessionAuthorId: "uid",
            authorId: "uid",
            authorName: "Jane Smith",
            authorImageUrl: nil,
            text: "Great session! 💪",
            dateCreated: Date()
        )
    }

    @MainActor
    static var mocks: [WorkoutSessionComment] {
        [
            WorkoutSessionComment(
                id: "comment-1",
                sessionId: "session-1",
                sessionAuthorId: "uid",
                authorId: "uid",
                authorName: "Jane Smith",
                authorImageUrl: nil,
                text: "Great session! 💪",
                dateCreated: Date().addingTimeInterval(-3600)
            ),
            WorkoutSessionComment(
                id: "comment-2",
                sessionId: "session-1",
                sessionAuthorId: "uid",
                authorId: "uid2",
                authorName: "John Doe",
                authorImageUrl: nil,
                text: "Impressive volume!",
                dateCreated: Date().addingTimeInterval(-1800)
            ),
            WorkoutSessionComment(
                id: "comment-3",
                sessionId: "session-1",
                sessionAuthorId: "uid",
                authorId: "uid",
                authorName: "Jane Smith",
                authorImageUrl: nil,
                text: "Thanks! Top set felt easy.",
                dateCreated: Date().addingTimeInterval(-900),
                parentId: "comment-2"
            )
        ]
    }

    /// Builds comments that actually belong to the session being previewed, with a mix of
    /// authors so the own-comment (delete) and other-author (report) swipe paths both appear.
    /// The hard-coded `mocks` above always sit on `session-1`, which never matches a real
    /// session id, so a preview built from them renders the empty state instead.
    @MainActor
    static func mocks(sessionId: String, currentUserId: String = "mock_user_123") -> [WorkoutSessionComment] {
        PreviewCommentAuthor.all(currentUserId: currentUserId).enumerated().map { index, author in
            WorkoutSessionComment(
                id: "preview-comment-\(index + 1)",
                sessionId: sessionId,
                sessionAuthorId: currentUserId,
                authorId: author.id,
                authorName: author.name,
                authorImageUrl: author.imageUrl,
                text: author.text,
                dateCreated: Date().addingTimeInterval(-Double(index + 1) * 5400)
            )
        }
    }

    /// A long list, for checking that scrolling works and the input bar stays anchored.
    @MainActor
    static func manyMocks(sessionId: String, count: Int = 40) -> [WorkoutSessionComment] {
        let base = mocks(sessionId: sessionId)
        return (0..<count).map { index in
            let source = base[index % base.count]
            return WorkoutSessionComment(
                id: "preview-comment-bulk-\(index)",
                sessionId: source.sessionId,
                sessionAuthorId: source.sessionAuthorId,
                authorId: source.authorId,
                authorName: source.authorName,
                authorImageUrl: source.authorImageUrl,
                text: source.text,
                dateCreated: Date().addingTimeInterval(-Double(index + 1) * 900)
            )
        }
    }
}

/// A struct rather than a tuple so the fields stay named at the use site.
private struct PreviewCommentAuthor {
    let id: String
    let name: String
    let imageUrl: String?
    let text: String

    static func all(currentUserId: String) -> [PreviewCommentAuthor] {
        [
            PreviewCommentAuthor(
                id: currentUserId,
                name: "Alice Cooper",
                imageUrl: "https://picsum.photos/id/64/200",
                text: "Great session! 💪"
            ),
            PreviewCommentAuthor(
                id: "uid2",
                name: "John Doe",
                imageUrl: "https://picsum.photos/id/91/200",
                text: "Impressive volume — what was your top set on bench?"
            ),
            PreviewCommentAuthor(
                id: "uid3",
                name: "Priya Raman",
                imageUrl: nil,
                text: "Third week in a row you've hit every set. Consistency is unreal."
            ),
            PreviewCommentAuthor(
                id: currentUserId,
                name: "Alice Cooper",
                imageUrl: "https://picsum.photos/id/64/200",
                text: "Adding this to my rotation."
            ),
            PreviewCommentAuthor(
                id: "uid4",
                name: "Marcus Webb",
                imageUrl: "https://picsum.photos/id/177/200",
                // Long enough to wrap several times, which is the case the row layout gets wrong first.
                text: "Honestly one of the better pushes I've seen from you. The RPE on those last "
                    + "two sets must have been brutal, but the bar speed still looked controlled the "
                    + "whole way through, which is the part most people miss when they chase numbers. "
                    + "Keep the accessory work in and this will carry straight into the next block."
            ),
            PreviewCommentAuthor(
                id: "uid5",
                name: "Sofia Lindqvist",
                imageUrl: nil,
                text: "🔥🔥🔥"
            )
        ]
    }
}
