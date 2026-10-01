import Foundation

@MainActor
class MockWorkoutSessionLikeService: WorkoutSessionLikeService {
    func likeSession(sessionId: String, authorId: String, userId: String) async throws { }
    func unlikeSession(sessionId: String, authorId: String, userId: String) async throws { }
}
