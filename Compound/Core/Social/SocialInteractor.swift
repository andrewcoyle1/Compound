import SwiftUI

@MainActor
protocol SocialInteractor: FollowInteractor, InviteAcceptInteractor, InviteLinkInteractor {
    var userImageUrl: String? { get }
    var currentUser: UserModel? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    var activityNotifications: [ActivityNotificationModel] { get }
    var incomingFollowRequests: [FollowRequestModel] { get }
    var followingWorkoutSessions: [WorkoutSessionModel] { get }
    var followingUsers: [UserModel] { get }
    var nudgedUserIdsToday: Set<String> { get }
    func nudgeUser(userId: String) async throws
    func fetchActivityNotifications() async throws
    func fetchSuggestedUsers() async throws -> [UserModel]
    func searchUsers(query: String) async throws -> [UserModel]
    func fetchWorkoutSession(id: String, authorId: String) async throws -> WorkoutSessionModel
    // MARK: - Challenges
    var challenges: [ChallengeModel] { get }
    func challengeProgress(challengeId: String) -> [String: Int]
    func refreshChallenges() async throws
    // MARK: - FeedLoading
    var hasLoadedFollowingSessions: Bool { get }
}

extension CoreInteractor: SocialInteractor {
    func searchUsers(query: String) async throws -> [UserModel] {
        let results = try await userManager.searchUsersByNameOrHandle(query: query)
        // Private profiles are found like any other; following one sends a request.
        return results.filter { $0.userId != currentUser?.userId }
    }
}
