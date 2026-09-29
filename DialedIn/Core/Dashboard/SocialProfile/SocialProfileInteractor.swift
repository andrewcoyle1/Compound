import SwiftUI

@MainActor
protocol SocialProfileInteractor: ReportInteractor, FollowInteractor {
    var followingUsers: [UserModel] { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    var activeTrainingProgram: TrainingProgram? { get }
    func fetchWorkoutSessions(authorId: String, limit: Int) async throws -> [WorkoutSessionModel]
    func fetchFollowers(userId: String) async throws -> [UserModel]
    func fetchUsers(userIds: [String]) async throws -> [UserModel]
    func blockUser(userId: String) async throws
    func unblockUser(userId: String) async throws
}

extension CoreInteractor: SocialProfileInteractor { }
