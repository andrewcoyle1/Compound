//
//  WorkoutSessionDetailInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 28/11/2025.
//

@MainActor
protocol WorkoutSessionDetailInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var allExercises: [ExerciseModel] { get }
    /// With `showBodyweightContribution`, the volume counts the bodyweight a movement lifts.
    var workoutSettings: WorkoutSettings { get }
    var currentWeightKilograms: Double? { get }
    func getUser(userId: String) async throws -> UserModel
    func saveWorkoutSession(_ session: WorkoutSessionModel) async throws
    func getPreference(templateId: String) -> ExerciseUnitPreference
    func setPreference(weightUnit: ExerciseWeightUnit?, distanceUnit: ExerciseDistanceUnit?, for templateId: String)
    func deleteWorkoutSession(id: String) async throws
    func workoutSessions(authoredBy authorId: String) -> [WorkoutSessionModel]
    var stravaIsConnected: Bool { get }
    func stravaUpdateActivity(_ activityId: Int, from session: WorkoutSessionModel) async throws
}

extension CoreInteractor: WorkoutSessionDetailInteractor {
    func stravaUpdateActivity(_ activityId: Int, from session: WorkoutSessionModel) async throws {
        try await stravaManager.updateActivity(activityId, from: session)
    }
}
