//
//  FirebaseCommentsService.swift
//  DialedIn
//
//  Created by Andrew Coyle on 08/03/2026.
//

import Foundation
import FirebaseFirestore

struct FirebaseCommentsService: CommentsManagerService {

    private var collection: CollectionReference {
        Firestore.firestore().collection("workout_session_comments")
    }

    func fetchComments(sessionId: String) async throws -> [WorkoutSessionComment] {
        let snapshot = try await collection
            .whereField("session_id", isEqualTo: sessionId)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard data["deleted_at"] == nil else { return nil }
            guard
                let sessionId = data["session_id"] as? String,
                let sessionAuthorId = data["session_author_id"] as? String,
                let authorId = data["author_id"] as? String,
                let text = data["text"] as? String,
                let dateCreatedTimestamp = data["date_created"] as? Timestamp
            else { return nil }
            return WorkoutSessionComment(
                id: doc.documentID,
                sessionId: sessionId,
                sessionAuthorId: sessionAuthorId,
                authorId: authorId,
                authorName: data["author_name"] as? String,
                authorImageUrl: data["author_image_url"] as? String,
                text: text,
                dateCreated: dateCreatedTimestamp.dateValue(),
                parentId: data["parent_id"] as? String,
                mentionedUserIds: data["mentioned_user_ids"] as? [String] ?? [],
                likedByUserIds: data["liked_by_user_ids"] as? [String] ?? [],
                hidden: data["hidden"] as? Bool
            )
        }
    }

    func addComment(_ comment: WorkoutSessionComment) async throws {
        try await collection.document(comment.id).setData([
            "id": comment.id,
            "session_id": comment.sessionId,
            "session_author_id": comment.sessionAuthorId,
            "author_id": comment.authorId,
            "author_name": comment.authorName as Any,
            "author_image_url": comment.authorImageUrl as Any,
            "text": comment.text,
            "date_created": Timestamp(date: comment.dateCreated),
            "parent_id": comment.parentId as Any,
            "mentioned_user_ids": comment.mentionedUserIds
        ])
    }

    func deleteComment(id: String) async throws {
        try await collection.document(id).updateData([
            "deleted_at": Timestamp(date: Date())
        ])
    }

    func toggleCommentLike(id: String, userId: String, isLiked: Bool) async throws {
        try await collection.document(id).updateData([
            "liked_by_user_ids": isLiked ? FieldValue.arrayUnion([userId]) : FieldValue.arrayRemove([userId])
        ])
    }
}
