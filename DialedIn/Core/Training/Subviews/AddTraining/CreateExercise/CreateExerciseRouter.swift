//
//  CreateExerciseRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/11/2025.
//

@MainActor
protocol CreateExerciseRouter: GlobalRouter {
    func showMuscleGroupPickerView(delegate: MuscleGroupPickerDelegate)
#if DEV || MOCK
func showDevSettingsView()
#endif
}

extension CoreRouter: CreateExerciseRouter { }
