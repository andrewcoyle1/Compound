import SwiftUI

@Observable
@MainActor
class TimerDurationPresenter {

    private let interactor: TimerDurationInteractor
    private let router: TimerDurationRouter

    private var settings: WorkoutSettings

    // Sensible defaults per exercise type (seconds)
    static let defaultDurations: [ExerciseType: Int] = [
        .compoundUpper: 180,
        .compoundLower: 180,
        .isolationUpper: 90,
        .isolationLower: 90,
        .core: 60
    ]

    // MARK: - Edit Sheet State

    var editingType: ExerciseType?

    var isEditingType: Bool {
        get { editingType != nil }
        set { if !newValue { editingType = nil } }
    }

    var editMinutes: Int = 1
    var editSeconds: Int = 30

    init(interactor: TimerDurationInteractor, router: TimerDurationRouter) {
        self.interactor = interactor
        self.router = router
        self.settings = interactor.workoutSettings
    }

    // MARK: - Duration Access

    func duration(for type: ExerciseType) -> Int {
        settings.restDurationsByExerciseType[type.rawValue] ?? Self.defaultDurations[type] ?? 90
    }

    func formattedDuration(for type: ExerciseType) -> String {
        let seconds = duration(for: type)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Actions

    func onEditPressed(type: ExerciseType) {
        let current = duration(for: type)
        editMinutes = current / 60
        editSeconds = current % 60
        editingType = type
    }

    func saveEdit() {
        guard let type = editingType else { return }
        let total = editMinutes * 60 + editSeconds
        settings.restDurationsByExerciseType[type.rawValue] = total
        Task {
            do {
                try await save()
            } catch {
                interactor.trackEvent(event: Event.saveFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Save Settings"), subtitle: String(localized: "Please try again."))
            }
        }
        editingType = nil
    }

    func resetDefaults() {
        settings.restDurationsByExerciseType = [:]
        Task {
            do {
                try await save()
            } catch {
                interactor.trackEvent(event: Event.saveFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Save Settings"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    // MARK: - Per-Exercise Overrides

    /// One row per exercise that has a rest override, resolved back to its name. Settings whose
    /// exercise is no longer in the library are dropped rather than shown as a blank row.
    var exerciseOverrides: [ExerciseOverride] {
        interactor.allExerciseSettings
            .compactMap { setting in
                guard let seconds = setting.restDurationOverride else { return nil }
                guard let exercise = interactor.allExercises.first(where: { $0.id == setting.id }) else { return nil }
                return ExerciseOverride(id: setting.id, name: exercise.name, seconds: seconds)
            }
            .sorted { $0.name < $1.name }
    }

    struct ExerciseOverride: Identifiable {
        let id: String
        let name: String
        let seconds: Int
    }

    /// Exercises without an override yet, which are the ones worth offering in the picker.
    var exercisesWithoutOverride: [ExerciseModel] {
        let overridden = Set(exerciseOverrides.map(\.id))
        return interactor.allExercises
            .filter { !overridden.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    var isAddingExerciseTimer: Bool = false
    var editingExerciseId: String?
    var editingExerciseName: String = ""

    var isEditingExercise: Bool {
        get { editingExerciseId != nil }
        set { if !newValue { editingExerciseId = nil } }
    }

    func onAddExerciseTimerPressed() {
        isAddingExerciseTimer = true
    }

    func onExercisePicked(_ exercise: ExerciseModel) {
        isAddingExerciseTimer = false
        let current = interactor.exerciseRestOverride(for: exercise.id) ?? settings.defaultRestDurationSeconds
        editMinutes = current / 60
        editSeconds = current % 60
        editingExerciseName = exercise.name
        editingExerciseId = exercise.id
    }

    func onEditExerciseOverridePressed(_ override: ExerciseOverride) {
        editMinutes = override.seconds / 60
        editSeconds = override.seconds % 60
        editingExerciseName = override.name
        editingExerciseId = override.id
    }

    /// Zero clears the override rather than storing a zero-second rest, which is what the same
    /// picker on the exercise's own settings screen already does. Stored, a zero would show up
    /// here as an override reading "0:00" that no screen offers a way to interpret, and the two
    /// screens writing one field would disagree about what an empty picker means.
    func saveExerciseEdit() {
        guard let exerciseId = editingExerciseId else { return }
        let total = editMinutes * 60 + editSeconds
        let seconds = total > 0 ? total : nil
        editingExerciseId = nil
        Task {
            do {
                try await interactor.setExerciseRestOverride(seconds, for: exerciseId)
            } catch {
                interactor.trackEvent(event: Event.saveFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Save Settings"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    func removeExerciseOverride(_ override: ExerciseOverride) {
        Task {
            do {
                try await interactor.setExerciseRestOverride(nil, for: override.id)
            } catch {
                interactor.trackEvent(event: Event.saveFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Save Settings"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    func formattedDuration(seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Lifecycle

    func onViewAppear(delegate: TimerDurationDelegate) {
        settings = interactor.workoutSettings
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: TimerDurationDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    // MARK: - Private

    private func save() async throws {
        try await interactor.saveWorkoutSettings(settings)
    }
}

extension TimerDurationPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: TimerDurationDelegate)
        case onDisappear(delegate: TimerDurationDelegate)
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .saveFail: return "TimerDurationView_Save_Fail"
            case .onAppear:    return "TimerDurationView_Appear"
            case .onDisappear: return "TimerDurationView_Disappear"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .saveFail(error: let error): return error.eventParameters
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            }
        }

        var type: LogType {
            switch self {
            case .saveFail: return .severe
            default: return .analytic
            }
        }
    }
}
