//
//  ExerciseFrequencyRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol ExerciseFrequencyRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showActivityView(delegate: ActivityDelegate)
}

extension CoreRouter: ExerciseFrequencyRouter { }
