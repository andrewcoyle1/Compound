import Foundation
import FirebaseFirestore

struct FirebaseWorkoutSessionLikeService: WorkoutSessionLikeService {

    func likeSession(sessionId: String, authorId: String, userId: String) async throws {
        let ref = Firestore.firestore()
            .collection("users").document(authorId)
            .collection("workout_sessions").document(sessionId)
        try await ref.updateData(["liked_by_user_ids": FieldValue.arrayUnion([userId])])
    }

    func unlikeSession(sessionId: String, authorId: String, userId: String) async throws {
        let ref = Firestore.firestore()
            .collection("users").document(authorId)
            .collection("workout_sessions").document(sessionId)
        try await ref.updateData(["liked_by_user_ids": FieldValue.arrayRemove([userId])])
    }
}
