//
//  WorkoutExerciseEquipmentSheetInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 19/02/2026.
//

@MainActor
protocol WorkoutExerciseEquipmentSheetInteractor: GlobalInteractor {
    var userId: String? { get }
    var workoutGymProfile: GymProfileModel? { get }
    var allExercises: [ExerciseModel] { get }
}

extension CoreInteractor: WorkoutExerciseEquipmentSheetInteractor { }
