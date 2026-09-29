import SwiftUI

@MainActor
protocol DashboardInteractor: FollowInteractor, InviteAcceptInteractor, InviteLinkInteractor {
    var userId: String? { get }
    var userImageUrl: String? { get }
    var currentUser: UserModel? { get }
    var draftMeal: MealLogModel? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    var activityNotifications: [ActivityNotificationModel] { get }
    var incomingFollowRequests: [FollowRequestModel] { get }
    var followingWorkoutSessions: [WorkoutSessionModel] { get }
    var followingUsers: [UserModel] { get }
    var activeTrainingProgram: TrainingProgram? { get }
    var nudgedUserIdsToday: Set<String> { get }
    func deleteDraftMeal() throws 
    func nudgeUser(userId: String) async throws
    func fetchActivityNotifications() async throws
    func fetchSuggestedUsers() async throws -> [UserModel]
    func getDailyTotals(dayKey: String) throws -> DailyMacroTarget
    func getDailyTarget(for date: Date, userId: String) async throws -> DailyMacroTarget?
    func fetchWorkoutSession(id: String, authorId: String) async throws -> WorkoutSessionModel
    // MARK: - Challenges
    var challenges: [ChallengeModel] { get }
    func challengeProgress(challengeId: String) -> [String: Int]
    func refreshChallenges() async throws
    // MARK: - FeedLoading
    var hasLoadedFollowingSessions: Bool { get }
}

extension CoreInteractor: DashboardInteractor { }
