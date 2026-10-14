//
//  WorkoutTrackerRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 09/12/2025.
//

import SwiftUI

@MainActor
protocol WorkoutTrackerRouter: GlobalRouter {
    func showExercisesPickerView(delegate: ExercisesPickerDelegate)
    func showWorkoutNotesView(delegate: WorkoutNotesDelegate)
    func showWorkoutSettingsView(delegate: WorkoutSettingsDelegate)
    func showGymProfileView(delegate: GymProfileDelegate)
    func showWorkoutSummary(session: WorkoutSessionModel)
    /// A requirement rather than the `GlobalRouter` helper alone, so a test can see the tracker
    /// leave when the workout is finished from the Live Activity.
    func dismissScreen()
}

extension CoreRouter: WorkoutTrackerRouter { }
