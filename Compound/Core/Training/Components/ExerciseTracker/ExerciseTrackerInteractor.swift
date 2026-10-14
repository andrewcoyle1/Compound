//
//  ExerciseTrackerInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 02/03/2026.
//

@MainActor
protocol ExerciseTrackerInteractor: GlobalInteractor {
    var userId: String? { get }
    var allExercises: [ExerciseModel] { get }
    var workoutGymProfile: GymProfileModel? { get }

    func getPreference(templateId: String) -> ExerciseUnitPreference
    func setWeightUnit(_ unit: ExerciseWeightUnit, for templateId: String)
    func setDistanceUnit(_ unit: ExerciseDistanceUnit, for templateId: String)

    /// The note kept on this exercise's own settings screen, if any.
    func exerciseNote(for exerciseId: String) -> String?
    func setExerciseNote(_ note: String?, for exerciseId: String) async throws
}

extension CoreInteractor: ExerciseTrackerInteractor { }
