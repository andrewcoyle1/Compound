//
//  ExerciseTrackerRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 02/03/2026.
//

@MainActor
protocol ExerciseTrackerRouter: GlobalRouter {
    func showWorkoutNotesView(delegate: WorkoutNotesDelegate)
}

extension CoreRouter: ExerciseTrackerRouter { }
