//
//  Samples+Social.swift
//  CompoundUnitTests
//
//  The fixed social samples behind contracts/firestore/{follow_request,activity_notification,
//  session_comment,challenge,challenge_progress,invite,share,report,username_reservation}. Two
//  parties throughout: `user_contract_full` acts (requests, comments, sends, reports) and
//  `user_contract_friend` is on the other end, so the rules tests can create each document as its
//  real writer. See FirestoreContractTests+Social.swift.
//

import Foundation
@testable import Compound

extension Samples {
    static let socialActor = "user_contract_full"
    static let socialFriend = "user_contract_friend"

    static let fullFollowRequest = FollowRequestModel(
        requesterId: socialActor,
        requesterName: "Ada Lovelace",
        requesterImageUrl: "https://example.com/ada.jpg",
        dateCreated: date("2026-10-14T09:10:11.125Z"),
        status: .pending
    )

    static let minimalFollowRequest = FollowRequestModel(
        requesterId: socialActor,
        requesterName: "Ada Lovelace",
        requesterImageUrl: nil,
        dateCreated: date("2026-10-14T09:10:11.125Z"),
        status: .pending
    )

    /// A reply to the recipient's comment that also names a share and a challenge, so every
    /// optional key is written.
    static let fullNotification: ActivityNotificationModel = {
        var notification = ActivityNotificationModel(
            id: "comment_comment_contract_full",
            type: .comment,
            actorId: socialActor,
            actorName: "Ada Lovelace",
            actorImageUrl: "https://example.com/ada.jpg",
            sessionId: "session_contract_full",
            sessionAuthorId: socialFriend,
            commentText: "Strong top set",
            dateCreated: date("2026-10-14T10:00:00.250Z"),
            isRead: false
        )
        notification.shareId = "share_contract_full"
        notification.isReply = true
        notification.challengeId = "challenge_contract_full"
        return notification
    }()

    /// A follow: no session behind it, so `session_id` is empty.
    static let minimalNotification = ActivityNotificationModel(
        id: "follow_user_contract_full",
        type: .follow,
        actorId: socialActor,
        actorName: "Ada Lovelace",
        actorImageUrl: nil,
        sessionId: "",
        sessionAuthorId: socialFriend,
        commentText: nil,
        dateCreated: date("2026-10-14T10:00:00.250Z"),
        isRead: true
    )

    /// Deleted, liked and hidden too: everything a comment carries over its life.
    static let fullComment = WorkoutSessionComment(
        id: "comment_contract_full",
        sessionId: "session_contract_full",
        sessionAuthorId: socialFriend,
        authorId: socialActor,
        authorName: "Ada Lovelace",
        authorImageUrl: "https://example.com/ada.jpg",
        text: "Strong top set, @Grace",
        dateCreated: date("2026-10-14T10:00:00.250Z"),
        deletedAt: date("2026-10-14T11:30:00.500Z"),
        parentId: "comment_contract_parent",
        mentionedUserIds: [socialFriend],
        likedByUserIds: [socialFriend],
        hidden: true
    )

    /// What `addComment` writes for a top-level comment from a nameless profile.
    static let minimalComment = WorkoutSessionComment(
        id: "comment_contract_minimal",
        sessionId: "session_contract_full",
        sessionAuthorId: socialFriend,
        authorId: socialActor,
        authorName: nil,
        authorImageUrl: nil,
        text: "Nice",
        dateCreated: date("2026-10-14T10:00:00.250Z")
    )

    static let fullChallenge = ChallengeModel(
        id: "challenge_contract_full",
        ownerId: socialActor,
        title: "October Grind",
        targetSessions: 12,
        startsAt: date("2026-10-01T00:00:00.000Z"),
        endsAt: date("2026-10-31T00:00:00.000Z"),
        memberIds: [socialActor, socialFriend],
        dateCreated: date("2026-09-30T18:20:00.750Z")
    )

    static let minimalChallenge = ChallengeModel(
        id: "challenge_contract_minimal",
        ownerId: socialActor,
        title: "Solo week",
        targetSessions: 1,
        startsAt: date("2026-10-12T00:00:00.000Z"),
        endsAt: date("2026-10-19T00:00:00.000Z"),
        memberIds: [socialActor],
        dateCreated: date("2026-10-12T07:00:00.000Z")
    )

    static let fullChallengeProgress = ChallengeProgressModel(sessions: 5, updatedAt: date("2026-10-13T18:35:10.500Z"))
    static let minimalChallengeProgress = ChallengeProgressModel(sessions: 1, updatedAt: nil)

    /// As the app creates it: unused, at the cap the rules require.
    static let fullInvite = InviteModel(code: "ABCD2345", inviterId: socialActor, dateCreated: date("2026-10-02T12:00:00.000Z"))
    static let minimalInvite = InviteModel(code: "WXYZ6789", inviterId: socialActor, dateCreated: date("2026-10-03T12:00:00.000Z"))

    /// A mesocycle, whose payload holds whole templates; the minimal case is the other kind.
    static let fullShare = ShareModel(
        id: "share_contract_full",
        fromUserId: socialActor,
        toUserId: socialFriend,
        payload: .mesocycle(fullMesocycle),
        dateCreated: date("2026-10-14T08:00:00.125Z"),
        status: .pending
    )

    static let minimalShare = ShareModel(
        id: "share_contract_minimal",
        fromUserId: socialActor,
        toUserId: socialFriend,
        payload: .template(minimalWorkoutTemplate),
        dateCreated: date("2026-10-14T08:00:00.125Z"),
        status: .pending
    )

    static let fullReport = ReportSubmission(
        reportId: "report_contract_full",
        reporterUserId: socialActor,
        reportedUserId: socialFriend,
        contentType: .comment,
        contentId: "comment_contract_full",
        reason: .harassment,
        notes: "Keeps posting this",
        createdAt: date("2026-10-14T12:00:00.000Z")
    )

    /// A profile report with no note: the two optionals the app writes as null.
    static let minimalReport = ReportSubmission(
        reportId: "report_contract_minimal",
        reporterUserId: socialActor,
        reportedUserId: nil,
        contentType: .user,
        contentId: socialFriend,
        reason: .spam,
        notes: nil,
        createdAt: date("2026-10-14T12:00:00.000Z")
    )

    static let fullUsernameReservation = UsernameReservation(userId: socialActor, dateCreated: date("2026-10-01T09:00:00.000Z"))
    /// Read back before the server has filled in the timestamp.
    static let minimalUsernameReservation = UsernameReservation(userId: socialActor, dateCreated: nil)
}

/// `usernames/{handle}`. The app has no type for it: `FirebaseUserQueryService` writes `user_id`
/// and a server timestamp, and reads `user_id` alone.
struct UsernameReservation {
    let userId: String
    let dateCreated: Date?
}
