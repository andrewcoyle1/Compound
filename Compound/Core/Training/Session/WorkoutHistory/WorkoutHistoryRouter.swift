//
//  WorkoutHistoryRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 28/11/2025.
//

@MainActor
protocol WorkoutHistoryRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate)
}

extension CoreRouter: WorkoutHistoryRouter { }
