//
//  FirestoreContractTests+Social.swift
//  CompoundUnitTests
//
//  The social documents under the Firestore contract. Other users and Cloud Functions read these,
//  so a bad write reaches more than its writer:
//  - Codable, through the real Firestore coders: follow requests
//    (`users/{target}/follow_requests/{requester_id}`), challenges (`challenges/{id}`), challenge
//    progress (`challenges/{id}/progress/{member_id}`, written only by the
//    `onWorkoutSessionEndedForChallenges` function), invites (`invites/{code}`) and shares
//    (`shares/{id}`).
//  - Plain dictionaries, which the app's services build and parse by hand: notifications
//    (`users/{uid}/notifications/{id}`), comments (`workout_session_comments/{id}`), reports
//    (`reports/{id}`) and username reservations (`usernames/{handle}`). Their parsers are private
//    and take a `QueryDocumentSnapshot`, which a test cannot build, so the round trip here mirrors
//    them line for line, and `serviceKeysMatchFixtures` fails when a service names a key the
//    fixture lacks, or the reverse.
//  The fields functions/index.js reads, and the shapes it writes, are checked against these
//  fixtures in functions/rules.test.js. See FirestoreContractTests.swift.
//

import Foundation
import Testing
import FirebaseFirestore
@testable import Compound

extension FirestoreContractTests {

    static func socialContracts() throws -> [Contract] {
        [
            try contract(
                FollowRequestModel.self, directory: "follow_request",
                full: Samples.fullFollowRequest, minimal: Samples.minimalFollowRequest,
                // The collection-group query on `requester_id` and the `status` update and query in
                // `FirebaseUserQueryService`.
                namedFields: ([.requesterId, .status] as [FollowRequestModel.CodingKeys]).map(\.rawValue)
            ),
            try contract(
                ChallengeModel.self, directory: "challenge",
                full: Samples.fullChallenge, minimal: Samples.minimalChallenge,
                // The `array-contains` query and the `arrayRemove` on leaving.
                namedFields: [ChallengeModel.CodingKeys.memberIds.rawValue]
            ),
            try contract(
                ChallengeProgressModel.self, directory: "challenge_progress",
                full: Samples.fullChallengeProgress, minimal: Samples.minimalChallengeProgress, namedFields: []
            ),
            try contract(
                InviteModel.self, directory: "invite",
                full: Samples.fullInvite, minimal: Samples.minimalInvite,
                namedFields: [InviteModel.CodingKeys.inviterId.rawValue]
            ),
            try contract(
                ShareModel.self, directory: "share",
                full: Samples.fullShare, minimal: Samples.minimalShare,
                namedFields: [ShareModel.CodingKeys.status.rawValue]
            ),
            dictionaryContract(
                directory: "activity_notification",
                full: Samples.fullNotification, minimal: Samples.minimalNotification,
                read: NotificationMirror.read, write: NotificationMirror.write
            ),
            dictionaryContract(
                directory: "session_comment",
                full: Samples.fullComment, minimal: Samples.minimalComment,
                read: CommentMirror.read, write: CommentMirror.write
            ),
            dictionaryContract(
                directory: "report",
                full: Samples.fullReport, minimal: Samples.minimalReport,
                read: ReportMirror.read, write: ReportMirror.write
            ),
            dictionaryContract(
                directory: "username_reservation",
                full: Samples.fullUsernameReservation, minimal: Samples.minimalUsernameReservation,
                read: UsernameMirror.read, write: UsernameMirror.write
            )
        ]
    }

    /// A model the app reads and writes as a dictionary. Every key is named by hand, which
    /// `serviceKeysMatchFixtures` covers, so it lists no named fields of its own.
    static func dictionaryContract<T>(
        directory: String, full: T, minimal: T,
        read: @escaping ([String: Any]) throws -> T, write: @escaping (T) -> [String: Any]
    ) -> Contract {
        Contract(
            directory: directory,
            samples: ["full": write(full), "minimal": write(minimal)],
            roundTrip: { write(try read($0)) },
            namedFields: [],
            fullSample: full
        )
    }

    /// Exhaustive, as in `enumRawValuesMatch`; none of these is CaseIterable but `ReportReason`.
    static func socialEnums() -> [String: [String]] {
        let requestStatuses: [FollowRequestModel.Status] = [.pending, .accepted, .declined]
        for status in requestStatuses {
            switch status {
            case .pending, .accepted, .declined: break
            }
        }
        let shareStatuses: [ShareModel.Status] = [.pending, .accepted, .dismissed]
        for status in shareStatuses {
            switch status {
            case .pending, .accepted, .dismissed: break
            }
        }
        let activityTypes: [ActivityNotificationModel.ActivityType] = [
            .like, .comment, .follow, .nudge, .mention, .followAccepted, .share, .challengeComplete
        ]
        for type in activityTypes {
            switch type {
            case .like, .comment, .follow, .nudge, .mention, .followAccepted, .share, .challengeComplete: break
            }
        }
        let contentTypes: [ReportContentType] = [.comment, .session, .user]
        for type in contentTypes {
            switch type {
            case .comment, .session, .user: break
            }
        }
        return [
            "FollowRequestStatus": requestStatuses.map(\.rawValue),
            "ShareStatus": shareStatuses.map(\.rawValue),
            "ActivityType": activityTypes.map(\.rawValue),
            "ReportContentType": contentTypes.map(\.rawValue),
            "ReportReason": ReportReason.allCases.map(\.rawValue)
        ]
    }

    // MARK: - Tests

    /// Every quoted key a dictionary service writes or reads (`"key":` or `["key"]`) is a key of
    /// the model's full fixture, and every fixture key is one the service names.
    @Test("The dictionary services name exactly the keys of their full fixtures")
    func serviceKeysMatchFixtures() throws {
        let services: [(file: String, directory: String)] = [
            ("Compound/Managers/Notifications/FirebaseActivityNotificationService.swift", "activity_notification"),
            ("Compound/Managers/Social/FirebaseCommentsService.swift", "session_comment"),
            ("Compound/Managers/Reports/Remote/FirebaseReportService.swift", "report"),
            ("Compound/Managers/User/Services/FirebaseUserQueryService.swift", "username_reservation")
        ]
        let repo = Self.root.deletingLastPathComponent().deletingLastPathComponent()
        let key = try Regex(#""([a-z_]+)"\s*[:\]]"#)
        for service in services {
            var source = try String(contentsOf: repo.appendingPathComponent(service.file), encoding: .utf8)
            // The user query service holds more than usernames; only its last section writes them.
            if let start = source.range(of: "// MARK: - Usernames") {
                source = String(source[start.lowerBound...])
            }
            let named = Set(source.matches(of: key).compactMap { $0.output[1].substring.map(String.init) })
            let fixture = Set(try Self.taggedFixture(service.directory, "full").keys)
            #expect(named == fixture, "\(service.directory): \(service.file) names \(named.sorted()), full.json has \(fixture.sorted())")
        }
    }
}

// MARK: - Mirrors of the dictionary services

/// `FirebaseActivityNotificationService.parse(doc:)` and `addNotification`. The document id is not
/// in the data.
enum NotificationMirror {
    static func read(_ data: [String: Any]) throws -> ActivityNotificationModel {
        guard
            let typeRaw = data["type"] as? String,
            let type = ActivityNotificationModel.ActivityType(rawValue: typeRaw),
            let actorId = data["actor_id"] as? String,
            let actorName = data["actor_name"] as? String,
            let sessionId = data["session_id"] as? String,
            let sessionAuthorId = data["session_author_id"] as? String,
            let dateCreatedTimestamp = data["date_created"] as? Timestamp
        else { throw MirrorError.dropped }
        return ActivityNotificationModel(
            id: "notification_contract",
            type: type,
            actorId: actorId,
            actorName: actorName,
            actorImageUrl: data["actor_image_url"] as? String,
            sessionId: sessionId,
            sessionAuthorId: sessionAuthorId,
            commentText: data["comment_text"] as? String,
            dateCreated: dateCreatedTimestamp.dateValue(),
            isRead: data["is_read"] as? Bool ?? false,
            shareId: data["share_id"] as? String,
            isReply: data["is_reply"] as? Bool ?? false,
            challengeId: data["challenge_id"] as? String
        )
    }

    static func write(_ notification: ActivityNotificationModel) -> [String: Any] {
        var data: [String: Any] = [
            "type": notification.type.rawValue,
            "actor_id": notification.actorId,
            "actor_name": notification.actorName,
            "session_id": notification.sessionId,
            "session_author_id": notification.sessionAuthorId,
            "date_created": Timestamp(date: notification.dateCreated),
            "is_read": notification.isRead
        ]
        if let actorImageUrl = notification.actorImageUrl { data["actor_image_url"] = actorImageUrl }
        if let commentText = notification.commentText { data["comment_text"] = commentText }
        if let shareId = notification.shareId { data["share_id"] = shareId }
        if notification.isReply { data["is_reply"] = true }
        if let challengeId = notification.challengeId { data["challenge_id"] = challengeId }
        return data
    }
}

/// `FirebaseCommentsService`: `addComment`'s dictionary, then the fields set later by name
/// (`deleted_at` by `deleteComment`, `liked_by_user_ids` by `toggleCommentLike`, `hidden` by the
/// `onReportCreated` function). The read is `fetchComments`' parse, except that it keeps a
/// deleted comment: the thread drops any document whose `deleted_at` is not nil, NSNull included,
/// so `deleted_at` must never be written as null. `addComment` passes a nil optional
/// `as Any`, which reaches Firestore as null; the mirror spells that `NSNull()`.
enum CommentMirror {
    static func read(_ data: [String: Any]) throws -> WorkoutSessionComment {
        guard
            let id = data["id"] as? String,
            let sessionId = data["session_id"] as? String,
            let sessionAuthorId = data["session_author_id"] as? String,
            let authorId = data["author_id"] as? String,
            let text = data["text"] as? String,
            let dateCreatedTimestamp = data["date_created"] as? Timestamp
        else { throw MirrorError.dropped }
        return WorkoutSessionComment(
            id: id,
            sessionId: sessionId,
            sessionAuthorId: sessionAuthorId,
            authorId: authorId,
            authorName: data["author_name"] as? String,
            authorImageUrl: data["author_image_url"] as? String,
            text: text,
            dateCreated: dateCreatedTimestamp.dateValue(),
            deletedAt: (data["deleted_at"] as? Timestamp)?.dateValue(),
            parentId: data["parent_id"] as? String,
            mentionedUserIds: data["mentioned_user_ids"] as? [String] ?? [],
            likedByUserIds: data["liked_by_user_ids"] as? [String] ?? [],
            hidden: data["hidden"] as? Bool
        )
    }

    static func write(_ comment: WorkoutSessionComment) -> [String: Any] {
        var data: [String: Any] = [
            "id": comment.id,
            "session_id": comment.sessionId,
            "session_author_id": comment.sessionAuthorId,
            "author_id": comment.authorId,
            "author_name": comment.authorName ?? NSNull(),
            "author_image_url": comment.authorImageUrl ?? NSNull(),
            "text": comment.text,
            "date_created": Timestamp(date: comment.dateCreated),
            "parent_id": comment.parentId ?? NSNull(),
            "mentioned_user_ids": comment.mentionedUserIds
        ]
        if let deletedAt = comment.deletedAt { data["deleted_at"] = Timestamp(date: deletedAt) }
        if !comment.likedByUserIds.isEmpty { data["liked_by_user_ids"] = comment.likedByUserIds }
        if let hidden = comment.hidden { data["hidden"] = hidden }
        return data
    }
}

/// `FirebaseReportService.submit`, which writes a nil optional as null. Nothing in the app reads a
/// report back; `onReportCreated` does. `status` is always written `open`.
enum ReportMirror {
    static func read(_ data: [String: Any]) throws -> ReportSubmission {
        guard
            let id = data["id"] as? String,
            let reporterId = data["reporter_id"] as? String,
            let contentType = (data["target_type"] as? String).flatMap(ReportContentType.init),
            let contentId = data["target_id"] as? String,
            let reason = (data["reason"] as? String).flatMap(ReportReason.init),
            let dateCreated = data["date_created"] as? Timestamp
        else { throw MirrorError.dropped }
        return ReportSubmission(
            reportId: id,
            reporterUserId: reporterId,
            reportedUserId: data["target_author_id"] as? String,
            contentType: contentType,
            contentId: contentId,
            reason: reason,
            notes: data["note"] as? String,
            createdAt: dateCreated.dateValue()
        )
    }

    static func write(_ report: ReportSubmission) -> [String: Any] {
        [
            "id": report.reportId,
            "reporter_id": report.reporterUserId,
            "target_type": report.contentType.rawValue,
            "target_id": report.contentId,
            "target_author_id": report.reportedUserId ?? NSNull(),
            "reason": report.reason.rawValue,
            "note": report.notes ?? NSNull(),
            "status": "open",
            "date_created": Timestamp(date: report.createdAt)
        ]
    }
}

/// `FirebaseUserQueryService.usernameOwner` and `reserveUsername`, which writes
/// `FieldValue.serverTimestamp()`; the fixture holds the Timestamp the server fills in.
enum UsernameMirror {
    static func read(_ data: [String: Any]) throws -> UsernameReservation {
        guard let userId = data["user_id"] as? String else { throw MirrorError.dropped }
        return UsernameReservation(userId: userId, dateCreated: (data["date_created"] as? Timestamp)?.dateValue())
    }

    static func write(_ reservation: UsernameReservation) -> [String: Any] {
        var data: [String: Any] = ["user_id": reservation.userId]
        if let dateCreated = reservation.dateCreated { data["date_created"] = Timestamp(date: dateCreated) }
        return data
    }
}

/// The app's parser would have returned nil: the document is skipped.
enum MirrorError: Error { case dropped }
