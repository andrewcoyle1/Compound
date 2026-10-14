//
//  ExerciseTrackerRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 02/03/2026.
//

@MainActor
protocol ExerciseTrackerRouter: GlobalRouter {
    func showWorkoutNotesView(delegate: WorkoutNotesDelegate)
    func showWorkoutExerciseEquipmentSheetView(delegate: WorkoutExerciseEquipmentSheetDelegate)
    func showExerciseSettingsView(delegate: ExerciseSettingsDelegate)
    func showSetTargetView(delegate: SetTargetDelegate)
    /// `alternativeIds` are the plan's substitutions, listed first.
    func showSwapExercisePickerView(alternativeIds: [String], onSelect: @escaping (ExerciseModel) -> Void)
}

extension CoreRouter: ExerciseTrackerRouter { }
