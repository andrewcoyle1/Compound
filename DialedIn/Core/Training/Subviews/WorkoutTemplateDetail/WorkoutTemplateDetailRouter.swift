//
//  WorkoutTemplateDetailRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

import SwiftUI

@MainActor
protocol WorkoutTemplateDetailRouter: GlobalRouter {
    #if DEV || MOCK
    func showDevSettingsView()
    #endif
    func showCreateWorkoutView(delegate: CreateWorkoutDelegate)
    func showWorkoutTrackerView()
    func showExerciseModelDetailView(delegate: ExerciseModelDetailDelegate)
    func showShareToFollowerView(delegate: ShareToFollowerDelegate)
}

extension CoreRouter: WorkoutTemplateDetailRouter { }
