//
//  SwapExercisePickerPresenter.swift
//  Compound
//

import Foundation

@Observable
@MainActor
class SwapExercisePickerPresenter {
    private let interactor: SwapExercisePickerInteractor
    private let router: SwapExercisePickerRouter
    let onSelect: (ExerciseModel) -> Void

    var searchText: String = ""

    var filteredExercises: [ExerciseModel] {
        guard !searchText.isEmpty else { return interactor.allExercises }
        return interactor.allExercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    init(
        interactor: SwapExercisePickerInteractor,
        router: SwapExercisePickerRouter,
        onSelect: @escaping (ExerciseModel) -> Void
    ) {
        self.interactor = interactor
        self.router = router
        self.onSelect = onSelect
    }

    func onExerciseSelected(_ exercise: ExerciseModel) {
        onSelect(exercise)
        router.dismissScreen()
    }

    func onDismissPressed() {
        router.dismissScreen()
    }
}
