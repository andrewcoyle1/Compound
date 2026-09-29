import SwiftUI

@Observable
@MainActor
class ExerciseListBuilderPresenter {
    
    private let interactor: ExerciseListBuilderInteractor
    private let router: ExerciseListBuilderRouter

    private(set) var isLoading: Bool = false
    private(set) var searchExerciseTask: Task<Void, Never>?
    
    /// The filter bar's state. Every list below runs through it, so a filter set with no search
    /// text narrows the browse sections too — not only the search results.
    var filters = ExerciseFilters()

    var userExercises: [ExerciseModel] {
        matching(interactor.userExercises)
    }

    var systemExercises: [ExerciseModel] {
        matching(interactor.systemExercises)
    }

    var filteredExercises: [ExerciseModel] {
        matching(filterBySearchText(interactor.allExercises))
    }

    var searchText: String = ""
    var selectedWorkoutTemplate: WorkoutTemplateModel?
    var selectedExerciseModel: ExerciseModel?

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedSearchText: String {
        trimmedSearchText.lowercased()
    }

    var currentUser: UserModel? {
        interactor.currentUser
    }

    init(interactor: ExerciseListBuilderInteractor, router: ExerciseListBuilderRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    // MARK: - Filtering

    var gymProfiles: [GymProfileModel] {
        interactor.gymProfiles.filter { $0.deletedAt == nil }
    }

    /// The chosen gym's *active* equipment. A profile lists every equipment type with an on/off
    /// flag, so the inactive ones are exactly the things that gym does not have.
    private var availableEquipment: Set<EquipmentRef> {
        guard
            let gymProfileId = filters.gymProfileId,
            let profile = gymProfiles.first(where: { $0.id == gymProfileId })
        else {
            return []
        }
        return Set(profile.allEquipment.filter(\.isActive).map(\.ref))
    }

    private func matching(_ exercises: [ExerciseModel]) -> [ExerciseModel] {
        let equipment = availableEquipment
        return exercises
            .filter { filters.matches($0, availableEquipment: equipment) }
            .sortedByKeyPath(keyPath: \.name, ascending: true)
    }

    private func filterBySearchText(_ exercises: [ExerciseModel]) -> [ExerciseModel] {
        guard !normalizedSearchText.isEmpty else { return exercises }
        return exercises.filter { matchesSearchText($0, normalizedQuery: normalizedSearchText) }
    }

    /// Muscle group names are searchable too: "quads" should find a squat even though the word is
    /// in neither the name nor the description.
    private func matchesSearchText(_ exercise: ExerciseModel, normalizedQuery: String) -> Bool {
        if exercise.name.lowercased().contains(normalizedQuery) { return true }
        if let description = exercise.description?.lowercased(), description.contains(normalizedQuery) { return true }
        if exercise.alternateNames.contains(where: { $0.lowercased().contains(normalizedQuery) }) { return true }
        if exercise.muscleGroups.keys.contains(where: { $0.rawValue.lowercased().contains(normalizedQuery) }) { return true }
        return false
    }

    /// The name shown on the "Gym" chip.
    var gymFilterLabel: String {
        guard
            let gymProfileId = filters.gymProfileId,
            let profile = gymProfiles.first(where: { $0.id == gymProfileId })
        else {
            return String(localized: "Gym")
        }
        return profile.name
    }

    func onResetFiltersPressed() {
        guard filters.isActive else { return }
        interactor.trackEvent(event: Event.filtersReset)
        filters.reset()
    }

    func onFilterChanged(_ name: String) {
        interactor.trackEvent(event: Event.filterChanged(name: name))
    }

    func onAddExercisePressed() {
        interactor.trackEvent(event: Event.onAddExercisePressed)
        router.showCreateExerciseView()
    }

    /// Picking an exercise is what this screen exists for, and every row used to call the delegate
    /// closure straight from the view — so the one action worth measuring here was never measured.
    func onExercisePressed(exercise: ExerciseModel, onExerciseSelectionChanged: ((ExerciseModel) -> Void)?) {
        interactor.trackEvent(event: Event.exerciseSelected(exercise: exercise))
        onExerciseSelectionChanged?(exercise)
    }

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case onAddExercisePressed
        case filtersReset
        case filterChanged(name: String)
        case exerciseSelected(exercise: ExerciseModel)

        var eventName: String {
            switch self {
            case .onAppear:             return "ExercisesView_Appear"
            case .onDisappear:          return "ExercisesView_Disappear"
            case .onAddExercisePressed: return "ExercisesView_AddExercisePressed"
            case .filtersReset:         return "ExercisesView_Filters_Reset"
            case .filterChanged:        return "ExercisesView_Filter_Changed"
            case .exerciseSelected:     return "ExercisesView_Exercise_Selected"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .filterChanged(name: let name):
                return ["filter": name]
            // Id and name rather than the whole model: this fires on every tap, and the rest of the
            // record is recoverable from the id.
            case .exerciseSelected(exercise: let exercise):
                return ["exercise_id": exercise.id, "exercise_name": exercise.name]
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }

}
