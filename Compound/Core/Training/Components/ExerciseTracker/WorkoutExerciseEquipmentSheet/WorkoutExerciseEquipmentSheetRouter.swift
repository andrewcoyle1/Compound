//
//  WorkoutExerciseEquipmentSheetRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 19/02/2026.
//

@MainActor
protocol WorkoutExerciseEquipmentSheetRouter: GlobalRouter {
    func showGymProfileView(delegate: GymProfileDelegate)
}

extension CoreRouter: WorkoutExerciseEquipmentSheetRouter { }
