//
//  CommentsManagerService.swift
//  DialedIn
//
//  Created by Andrew Coyle on 08/03/2026.
//

@MainActor
protocol CommentsManagerService {
    func fetchComments(sessionId: String) async throws -> [WorkoutSessionComment]
    func addComment(_ comment: WorkoutSessionComment) async throws
    func deleteComment(id: String) async throws
    /// Adds (`isLiked`) or removes the user's like. Idempotent: it sets the state rather than
    /// flipping whatever is stored, so a repeated tap cannot land on the wrong side.
    func toggleCommentLike(id: String, userId: String, isLiked: Bool) async throws
}
