//
//  SwapExercisePickerInteractor.swift
//  Compound
//

@MainActor
protocol SwapExercisePickerInteractor: GlobalInteractor {
    var allExercises: [ExerciseModel] { get }
}

extension CoreInteractor: SwapExercisePickerInteractor {}
