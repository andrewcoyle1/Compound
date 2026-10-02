import Foundation

@MainActor
class MockUserQueryService: UserQueryService {
    /// Follow requests by target id, standing in for each user's `follow_requests` subcollection.
    /// Seeded with one request to the signed-in mock user so the Notifications screen has one to answer.
    private(set) var followRequests: [String: [FollowRequestModel]] = [
        "mock_user_123": [
            FollowRequestModel(
                requesterId: "user2",
                requesterName: "Bob Martinez",
                requesterImageUrl: "https://picsum.photos/seed/bob/200",
                dateCreated: Date().addingTimeInterval(-1800),
                status: .pending
            )
        ]
    ]
    /// Live listeners by target id, told whenever that target's requests change.
    private var listeners: [String: [UUID: @MainActor ([FollowRequestModel]) -> Void]] = [:]

    func fetchFollowers(userId: String) async throws -> [UserModel] { [] }
    func searchUsers(query: String) async throws -> [UserModel] { [] }
    func fetchSuggestedUsers(limit: Int) async throws -> [UserModel] { Array(UserModel.mocks.prefix(limit)) }
    func fetchUsers(userIds: [String]) async throws -> [UserModel] {
        UserModel.mocks.filter { userIds.contains($0.userId) }
    }

    func sendFollowRequest(_ request: FollowRequestModel, targetId: String) async throws {
        followRequests[targetId, default: []].removeAll { $0.requesterId == request.requesterId }
        followRequests[targetId, default: []].append(request)
        notifyListeners(targetId: targetId)
    }

    func deleteFollowRequest(requesterId: String, targetId: String) async throws {
        followRequests[targetId]?.removeAll { $0.requesterId == requesterId }
        notifyListeners(targetId: targetId)
    }

    func updateFollowRequestStatus(_ status: FollowRequestModel.Status, requesterId: String, targetId: String) async throws {
        guard let index = followRequests[targetId]?.firstIndex(where: { $0.requesterId == requesterId }) else { return }
        followRequests[targetId]?[index].status = status
        notifyListeners(targetId: targetId)
    }

    func fetchPendingFollowRequests(userId: String) async throws -> [FollowRequestModel] {
        pending(for: userId)
    }

    func fetchSentFollowRequestTargetIds(requesterId: String) async throws -> [String] {
        followRequests.compactMap { targetId, requests in
            requests.contains { $0.requesterId == requesterId && $0.status == .pending } ? targetId : nil
        }
    }

    /// Every follower removed, in order, since nothing here holds other users' documents.
    private(set) var removedFollowerIds: [String] = []

    func removeFollower(followerId: String) async throws {
        removedFollowerIds.append(followerId)
    }

    func listenToPendingFollowRequests(
        userId: String,
        onChange: @escaping @MainActor ([FollowRequestModel]) -> Void
    ) -> @MainActor () -> Void {
        let token = UUID()
        listeners[userId, default: [:]][token] = onChange
        onChange(pending(for: userId))
        return { [weak self] in self?.listeners[userId]?[token] = nil }
    }

    private func pending(for userId: String) -> [FollowRequestModel] {
        (followRequests[userId] ?? []).filter { $0.status == .pending }
    }

    private func notifyListeners(targetId: String) {
        let requests = pending(for: targetId)
        listeners[targetId]?.values.forEach { $0(requests) }
    }

    // MARK: Usernames

    /// Reservations by handle, standing in for `usernames/{handle}`, seeded from the mock roster.
    private(set) var usernameReservations: [String: String] = UserModel.mockUsernames
        .reduce(into: ["alice.cooper": "mock_user_123"]) { $0[$1.value] = $1.key }

    func usernameOwner(_ handle: String) async throws -> String? {
        usernameReservations[handle]
    }

    func reserveUsername(_ handle: String, userId: String) async throws {
        guard usernameReservations[handle] == nil else { throw UsernameError.taken }
        usernameReservations[handle] = userId
    }

    func searchUsers(usernamePrefix: String) async throws -> [UserModel] {
        UserModel.mocks.filter { $0.username?.hasPrefix(usernamePrefix) == true }
    }
}
