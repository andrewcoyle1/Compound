//
//  WeightRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol WeightRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showExerciseFrequencyView(delegate: ExerciseFrequencyDelegate)
}

extension CoreRouter: WeightRouter { }
