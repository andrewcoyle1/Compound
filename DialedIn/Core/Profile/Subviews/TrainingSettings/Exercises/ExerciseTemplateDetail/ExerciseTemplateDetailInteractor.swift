//
//  ExerciseModelDetailInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/11/2025.
//

@MainActor
protocol ExerciseModelDetailInteractor {
    var currentUser: UserModel? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    func getPreference(templateId: String) -> ExerciseUnitPreference
    func deleteExerciseModel(exerciseId: String) async throws
}

extension CoreInteractor: ExerciseModelDetailInteractor { }
