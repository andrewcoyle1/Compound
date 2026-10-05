//
//  TodaysWorkoutCardRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 09/03/2026.
//

@MainActor
protocol TodaysWorkoutCardRouter: GlobalRouter {
    func showWorkoutTrackerView()
    func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate)
    func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate)
}

extension CoreRouter: TodaysWorkoutCardRouter { }
