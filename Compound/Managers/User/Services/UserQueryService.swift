@MainActor
protocol UserQueryService {
    func fetchFollowers(userId: String) async throws -> [UserModel]
    func searchUsers(query: String) async throws -> [UserModel]
    /// The newest accounts, for a reader who follows nobody yet. Excluding the reader and the
    /// people they already follow is the caller's job.
    func fetchSuggestedUsers(limit: Int) async throws -> [UserModel]
    /// Profiles by id, in no particular order; ids with no profile are skipped.
    func fetchUsers(userIds: [String]) async throws -> [UserModel]

    // MARK: Follow requests — users/{targetId}/follow_requests/{requesterId}

    func sendFollowRequest(_ request: FollowRequestModel, targetId: String) async throws
    func deleteFollowRequest(requesterId: String, targetId: String) async throws
    func updateFollowRequestStatus(_ status: FollowRequestModel.Status, requesterId: String, targetId: String) async throws
    /// Pending requests waiting on `userId`.
    func fetchPendingFollowRequests(userId: String) async throws -> [FollowRequestModel]
    /// The ids of the profiles `requesterId` has a pending request with.
    func fetchSentFollowRequestTargetIds(requesterId: String) async throws -> [String]
    /// Takes the caller out of `followerId`'s following list. That is a write to someone else's
    /// document, so it goes through the `removeFollower` Cloud Function.
    func removeFollower(followerId: String) async throws
    /// Pending requests waiting on `userId`, delivered now and again on every change until the
    /// returned closure is called.
    func listenToPendingFollowRequests(
        userId: String,
        onChange: @escaping @MainActor ([FollowRequestModel]) -> Void
    ) -> @MainActor () -> Void

    // MARK: Usernames — usernames/{handle} with { user_id, date_created }

    /// The id of the user holding `handle`, or nil when it is free.
    func usernameOwner(_ handle: String) async throws -> String?
    /// Creates the reservation. Throws when it already exists (rules allow create, never update).
    func reserveUsername(_ handle: String, userId: String) async throws
    /// Users whose `username` starts with `prefix`.
    func searchUsers(usernamePrefix: String) async throws -> [UserModel]
}
