//
//  MockCommentsService.swift
//  DialedIn
//
//  Created by Andrew Coyle on 08/03/2026.
//

import Foundation

@MainActor
class MockCommentsService: CommentsManagerService {

    private var comments: [WorkoutSessionComment]
    private let delay: Double
    private let showError: Bool

    init(comments: [WorkoutSessionComment]? = nil, delay: Double = 0.0, showError: Bool = false) {
        self.comments = comments ?? WorkoutSessionComment.mocks
        self.delay = delay
        self.showError = showError
    }

    private func simulateRequest() async throws {
        if delay > 0 {
            try await Task.sleep(for: .seconds(delay))
        }
        if showError {
            throw URLError(.unknown)
        }
    }

    func fetchComments(sessionId: String) async throws -> [WorkoutSessionComment] {
        try await simulateRequest()
        return comments.filter { $0.sessionId == sessionId && $0.deletedAt == nil }
    }

    func addComment(_ comment: WorkoutSessionComment) async throws {
        try await simulateRequest()
        comments.append(comment)
    }

    func deleteComment(id: String) async throws {
        try await simulateRequest()
        if let index = comments.firstIndex(where: { $0.id == id }) {
            comments[index].deletedAt = Date()
        }
    }

    func toggleCommentLike(id: String, userId: String, isLiked: Bool) async throws {
        try await simulateRequest()
        guard let index = comments.firstIndex(where: { $0.id == id }) else { return }
        comments[index].likedByUserIds.removeAll { $0 == userId }
        if isLiked {
            comments[index].likedByUserIds.append(userId)
        }
    }
}
