//
//  WorkoutListRouterBuilder.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol WorkoutListRouterBuilder: GlobalRouter {
    #if DEV || MOCK
    func showDevSettingsView()
    #endif
    func showCreateWorkoutView(delegate: CreateWorkoutDelegate)
    func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate)
}

extension CoreRouter: WorkoutListRouterBuilder { }
