//
//  ActivityNotificationModel.swift
//  DialedIn
//
//  Created by Andrew Coyle on 08/03/2026.
//

import Foundation

struct ActivityNotificationModel: Identifiable {
    enum ActivityType: String {
        case like
        case comment
        /// Someone started following the user. `sessionId` is empty and `sessionAuthorId` is
        /// the followed user, since there is no session behind it.
        case follow
        /// Someone in the user's circle asked them to train today. Like `follow`, there is no
        /// session behind it: `sessionId` is empty and `sessionAuthorId` is the nudged user.
        case nudge
        /// Someone tagged the user in a comment. `commentText` is that comment.
        case mention
        /// A private profile accepted the user's follow request. Written by the
        /// `onFollowRequestUpdated` Cloud Function, with the accepting user as the actor.
        case followAccepted
        // MARK: - Sharing
        /// Someone shared a workout template or program with the user. `shareId` is the
        /// `shares/{id}` document, `commentText` the shared item's name, and `sessionId` is empty.
        case share
        // MARK: - Challenges
        /// The user reached a challenge's target. Written by the `onWorkoutSessionEndedForChallenges`
        /// Cloud Function with the user as their own actor; `challengeId` is the challenge and
        /// `commentText` its title.
        case challengeComplete = "challenge_complete"
    }

    let id: String
    let type: ActivityType
    let actorId: String
    let actorName: String
    let actorImageUrl: String?
    let sessionId: String
    let sessionAuthorId: String
    let commentText: String?
    let dateCreated: Date
    var isRead: Bool
    // MARK: - Sharing
    /// The `shares/{id}` document behind a `.share` notification; nil for every other type.
    var shareId: String?
    // MARK: - CommentLikes
    /// A `.comment` that answers the recipient's own comment rather than one on their workout.
    var isReply: Bool = false
    // MARK: - Challenges
    /// The `challenges/{id}` document behind a `.challengeComplete` notification; nil otherwise.
    var challengeId: String?
}

extension ActivityNotificationModel {
    static var mocks: [ActivityNotificationModel] {
        [
            ActivityNotificationModel(
                id: "mock_like_1",
                type: .like,
                actorId: "actor_1",
                actorName: "Jane Smith",
                actorImageUrl: nil,
                sessionId: "session_1",
                sessionAuthorId: "user_1",
                commentText: nil,
                dateCreated: Date().addingTimeInterval(-3600),
                isRead: false
            ),
            ActivityNotificationModel(
                id: "mock_comment_1",
                type: .comment,
                actorId: "actor_2",
                actorName: "John Doe",
                actorImageUrl: nil,
                sessionId: "session_1",
                sessionAuthorId: "user_1",
                commentText: "Great session!",
                dateCreated: Date().addingTimeInterval(-7200),
                isRead: true
            ),
            ActivityNotificationModel(
                id: "mock_follow_1",
                type: .follow,
                actorId: "actor_3",
                actorName: "Sam Lee",
                actorImageUrl: nil,
                sessionId: "",
                sessionAuthorId: "user_1",
                commentText: nil,
                dateCreated: Date().addingTimeInterval(-600),
                isRead: false
            )
        ]
    }
}
