//
//  TodaysWorkoutCardRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 09/03/2026.
//

@MainActor
protocol TodaysWorkoutCardRouter: GlobalRouter {
    func showWorkoutTrackerView()
    func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate)
}

extension CoreRouter: TodaysWorkoutCardRouter { }
