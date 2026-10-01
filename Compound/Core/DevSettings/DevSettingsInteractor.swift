//
//  DevSettingsInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol DevSettingsInteractor: GlobalInteractor {
    var auth: UserAuthInfo? { get }
    var currentUser: UserModel? { get }
    var activeTests: ActiveABTests { get }
    var activeSession: WorkoutSessionModel? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    var userExercises: [ExerciseModel] { get }
    var systemExercises: [ExerciseModel] { get }
    var allExercises: [ExerciseModel] { get }
    var userWorkoutTemplates: [WorkoutTemplateModel] { get }
    var systemWorkoutTemplates: [WorkoutTemplateModel] { get }
    var allWorkoutTemplates: [WorkoutTemplateModel] { get }
    func override(updatedTests: ActiveABTests) throws
    func getWorkoutSession(id: String) async throws -> WorkoutSessionModel
    func signOut() async throws
}

extension CoreInteractor: DevSettingsInteractor { }
