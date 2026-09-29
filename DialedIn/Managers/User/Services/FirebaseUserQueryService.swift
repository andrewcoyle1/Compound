import Foundation
import FirebaseFirestore
import FirebaseFunctions

struct FirebaseUserQueryService: UserQueryService {

    func fetchFollowers(userId: String) async throws -> [UserModel] {
        try await Firestore.firestore()
            .collection("users")
            .whereField(UserModel.CodingKeys.followingIds.rawValue, arrayContains: userId)
            .limit(to: 200)
            .getAllDocuments()
    }

    func searchUsers(query: String) async throws -> [UserModel] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let capitalizedQuery = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        let field = UserModel.CodingKeys.submittedFirstName.rawValue

        return try await Firestore.firestore()
            .collection("users")
            .whereField(field, isGreaterThanOrEqualTo: capitalizedQuery)
            .whereField(field, isLessThan: capitalizedQuery + "\u{f8ff}")
            .limit(to: 20)
            .getAllDocuments()
    }

    // ponytail: newest accounts, not the most active — swap for a follower-count order once one is stored
    func fetchSuggestedUsers(limit: Int) async throws -> [UserModel] {
        try await Firestore.firestore()
            .collection("users")
            .order(by: UserModel.CodingKeys.creationDate.rawValue, descending: true)
            .limit(to: limit)
            .getAllDocuments()
    }

    /// `in` takes at most 30 values, so larger lists go in chunks.
    func fetchUsers(userIds: [String]) async throws -> [UserModel] {
        var users: [UserModel] = []
        for start in stride(from: 0, to: userIds.count, by: 30) {
            let chunk = Array(userIds[start..<min(start + 30, userIds.count)])
            let page: [UserModel] = try await Firestore.firestore()
                .collection("users")
                .whereField(UserModel.CodingKeys.userId.rawValue, in: chunk)
                .getAllDocuments()
            users += page
        }
        return users
    }

    // MARK: Follow requests

    private func followRequests(targetId: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(targetId).collection("follow_requests")
    }

    func sendFollowRequest(_ request: FollowRequestModel, targetId: String) async throws {
        // Encoded first so the write itself can be awaited; `setData(from:)` does not report a rules
        // rejection to the caller.
        let data = try Firestore.Encoder().encode(request)
        try await followRequests(targetId: targetId).document(request.requesterId).setData(data)
    }

    func deleteFollowRequest(requesterId: String, targetId: String) async throws {
        try await followRequests(targetId: targetId).document(requesterId).delete()
    }

    func updateFollowRequestStatus(_ status: FollowRequestModel.Status, requesterId: String, targetId: String) async throws {
        try await followRequests(targetId: targetId).document(requesterId).updateData([
            FollowRequestModel.CodingKeys.status.rawValue: status.rawValue
        ])
    }

    private func pendingFollowRequests(targetId: String) -> Query {
        followRequests(targetId: targetId)
            .whereField(FollowRequestModel.CodingKeys.status.rawValue, isEqualTo: FollowRequestModel.Status.pending.rawValue)
            .limit(to: 100)
    }

    func fetchPendingFollowRequests(userId: String) async throws -> [FollowRequestModel] {
        try await pendingFollowRequests(targetId: userId).getAllDocuments()
    }

    func removeFollower(followerId: String) async throws {
        _ = try await Functions.functions(region: "us-central1")
            .httpsCallable("removeFollower")
            .call(["followerId": followerId])
    }

    /// Snapshot callbacks arrive on the main queue (Firestore's default). A failed snapshot, such as
    /// a rules rejection after sign-out, is skipped rather than clearing the list.
    func listenToPendingFollowRequests(
        userId: String,
        onChange: @escaping @MainActor ([FollowRequestModel]) -> Void
    ) -> @MainActor () -> Void {
        let registration = pendingFollowRequests(targetId: userId).addSnapshotListener { snapshot, _ in
            guard let snapshot else { return }
            let requests = snapshot.documents.compactMap { try? $0.data(as: FollowRequestModel.self) }
            MainActor.assumeIsolated { onChange(requests) }
        }
        return { registration.remove() }
    }

    /// Requests live under their target, so the reader's own outgoing ones are a collection-group
    /// query; the target is the parent of the `follow_requests` collection.
    func fetchSentFollowRequestTargetIds(requesterId: String) async throws -> [String] {
        try await Firestore.firestore()
            .collectionGroup("follow_requests")
            .whereField(FollowRequestModel.CodingKeys.requesterId.rawValue, isEqualTo: requesterId)
            .whereField(FollowRequestModel.CodingKeys.status.rawValue, isEqualTo: FollowRequestModel.Status.pending.rawValue)
            .getDocuments()
            .documents
            .compactMap { $0.reference.parent.parent?.documentID }
    }
}

// MARK: - Usernames

extension FirebaseUserQueryService {

    private func reservation(_ handle: String) -> DocumentReference {
        Firestore.firestore().collection("usernames").document(handle)
    }

    func usernameOwner(_ handle: String) async throws -> String? {
        let snapshot = try await reservation(handle).getDocument()
        guard snapshot.exists else { return nil }
        return snapshot.data()?["user_id"] as? String
    }

    /// A plain `setData`: on an existing document that is an update, which rules refuse, so a
    /// handle someone else reserved in the meantime fails here rather than being overwritten.
    func reserveUsername(_ handle: String, userId: String) async throws {
        try await reservation(handle).setData([
            "user_id": userId,
            "date_created": FieldValue.serverTimestamp()
        ])
    }

    /// A single-field range on `username`, which Firestore indexes automatically.
    func searchUsers(usernamePrefix: String) async throws -> [UserModel] {
        let field = UserModel.CodingKeys.username.rawValue
        return try await Firestore.firestore()
            .collection("users")
            .whereField(field, isGreaterThanOrEqualTo: usernamePrefix)
            .whereField(field, isLessThan: usernamePrefix + "\u{f8ff}")
            .limit(to: 20)
            .getAllDocuments()
    }
}
