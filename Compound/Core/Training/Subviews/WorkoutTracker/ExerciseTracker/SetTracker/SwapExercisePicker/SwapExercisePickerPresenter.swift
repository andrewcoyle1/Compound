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
    /// The plan's substitutions for the exercise being swapped, in the plan's order.
    private let alternativeIds: [String]
    let onSelect: (ExerciseModel) -> Void

    var searchText: String = ""

    /// The plan's substitutions found in the library, listed before it. An id the library no
    /// longer holds is skipped.
    var plannedAlternatives: [ExerciseModel] {
        let library = interactor.allExercises
        return alternativeIds
            .compactMap { id in library.first { $0.id == id } }
            .filter(matchesSearch)
    }

    var filteredExercises: [ExerciseModel] {
        interactor.allExercises.filter(matchesSearch)
    }

    init(
        interactor: SwapExercisePickerInteractor,
        router: SwapExercisePickerRouter,
        alternativeIds: [String] = [],
        onSelect: @escaping (ExerciseModel) -> Void
    ) {
        self.interactor = interactor
        self.router = router
        self.alternativeIds = alternativeIds
        self.onSelect = onSelect
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear(alternatives: alternativeIds.count))
    }

    func onExerciseSelected(_ exercise: ExerciseModel) {
        interactor.trackEvent(event: Event.exerciseSelected(planned: alternativeIds.contains(exercise.id)))
        onSelect(exercise)
        router.dismissScreen()
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    private func matchesSearch(_ exercise: ExerciseModel) -> Bool {
        searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText)
    }

    enum Event: LoggableEvent {
        case onAppear(alternatives: Int)
        case exerciseSelected(planned: Bool)

        var eventName: String {
            switch self {
            case .onAppear:         return "SwapExercisePicker_Appear"
            case .exerciseSelected: return "SwapExercisePicker_Exercise_Selected"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let alternatives):    return ["planned_alternatives": alternatives]
            case .exerciseSelected(let planned): return ["planned_alternative": planned]
            }
        }

        var type: LogType { .analytic }
    }
}
