//
//  ImportProgramRouter.swift
//  Compound
//

@MainActor
protocol ImportProgramRouter: GlobalRouter {
    /// The exercise library as a picker, its search already holding `name`.
    func showImportExercisePickerView(name: String, onSelect: @escaping @MainActor (ExerciseModel) -> Void)
}

extension CoreRouter: ImportProgramRouter { }
