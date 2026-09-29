//
//  CommentsManager.swift
//  DialedIn
//
//  Created by Andrew Coyle on 08/03/2026.
//

import Foundation

@Observable
@MainActor
class CommentsManager {

    private let service: CommentsManagerService

    init(service: CommentsManagerService) {
        self.service = service
    }

    func fetchComments(sessionId: String) async throws -> [WorkoutSessionComment] {
        try await service.fetchComments(sessionId: sessionId)
    }

    func addComment(_ comment: WorkoutSessionComment) async throws {
        try await service.addComment(comment)
    }

    func deleteComment(id: String) async throws {
        try await service.deleteComment(id: id)
    }

    func toggleCommentLike(id: String, userId: String, isLiked: Bool) async throws {
        try await service.toggleCommentLike(id: id, userId: userId, isLiked: isLiked)
    }
}
