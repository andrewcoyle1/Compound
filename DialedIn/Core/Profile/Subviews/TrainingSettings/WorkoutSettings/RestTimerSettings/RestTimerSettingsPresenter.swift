import SwiftUI

@Observable
@MainActor
class RestTimerSettingsPresenter {

    private let interactor: RestTimerSettingsInteractor
    private let router: RestTimerSettingsRouter

    private var settings: WorkoutSettings

    init(interactor: RestTimerSettingsInteractor, router: RestTimerSettingsRouter) {
        self.interactor = interactor
        self.router = router
        self.settings = interactor.workoutSettings
    }

    // MARK: - Navigation

    func onTimerDurationPressed() {
        router.showTimerDurationView(delegate: TimerDurationDelegate())
    }

    // MARK: - Behaviour Toggles

    var restAfterLastWarmUp: Bool {
        get { settings.restAfterLastWarmUp }
        set { settings.restAfterLastWarmUp = newValue; save() }
    }

    var restBetweenExercises: Bool {
        get { settings.restBetweenExercises }
        set { settings.restBetweenExercises = newValue; save() }
    }

    var restBetweenSideSets: Bool {
        get { settings.restBetweenSideSets }
        set { settings.restBetweenSideSets = newValue; save() }
    }

    // MARK: - Notification Toggles

    var useRestTimers: Bool {
        get { settings.useRestTimers }
        set { settings.useRestTimers = newValue; save() }
    }

    var restTimerPlaySound: Bool {
        get { settings.restTimerPlaySound }
        set { settings.restTimerPlaySound = newValue; save() }
    }

    var restTimerVibrate: Bool {
        get { settings.restTimerVibrate }
        set { settings.restTimerVibrate = newValue; save() }
    }

    // MARK: - Scaling

    var warmUpRestScaling: Double {
        get { settings.warmUpRestScaling }
        set { settings.warmUpRestScaling = newValue; save() }
    }

    var betweenExercisesRestScaling: Double {
        get { settings.betweenExercisesRestScaling }
        set { settings.betweenExercisesRestScaling = newValue; save() }
    }

    var sideSetRestScaling: Double {
        get { settings.sideSetRestScaling }
        set { settings.sideSetRestScaling = newValue; save() }
    }

    func formattedScaling(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    // MARK: - Scaling Sheet

    enum ScalingType: String, Identifiable, CaseIterable {
        var id: String { rawValue }
        case warmUp
        case betweenExercises
        case sideSets

        var label: String {
            switch self {
            case .warmUp:             return String(localized: "Rest After Last Warm-Up Set")
            case .betweenExercises:   return String(localized: "Rest Between Exercises")
            case .sideSets:           return String(localized: "Rest Between Left/Right Sets")
            }
        }
    }

    var editingScaling: ScalingType?

    var isEditingScaling: Bool {
        get { editingScaling != nil }
        set { if !newValue { editingScaling = nil } }
    }

    func onEditWarmUpScalingPressed() { editingScaling = .warmUp }
    func onEditBetweenExercisesScalingPressed() { editingScaling = .betweenExercises }
    func onEditSideSetsScalingPressed() { editingScaling = .sideSets }

    func currentScaling(for type: ScalingType) -> Double {
        switch type {
        case .warmUp:           return settings.warmUpRestScaling
        case .betweenExercises: return settings.betweenExercisesRestScaling
        case .sideSets:         return settings.sideSetRestScaling
        }
    }

    func updateScaling(for type: ScalingType, value: Double) {
        switch type {
        case .warmUp:           settings.warmUpRestScaling = value
        case .betweenExercises: settings.betweenExercisesRestScaling = value
        case .sideSets:         settings.sideSetRestScaling = value
        }
        save()
        editingScaling = nil
    }

    // MARK: - Lifecycle

    func onViewAppear(delegate: RestTimerSettingsDelegate) {
        settings = interactor.workoutSettings
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: RestTimerSettingsDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    // MARK: - Private

    private func save() {
        Task {
            do {
                try await interactor.saveWorkoutSettings(settings)
            } catch {
                interactor.trackEvent(event: Event.saveFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Save Settings"), subtitle: String(localized: "Please try again."))
            }
        }
    }
}

extension RestTimerSettingsPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: RestTimerSettingsDelegate)
        case onDisappear(delegate: RestTimerSettingsDelegate)
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .saveFail: return "RestTimerSettingsView_Save_Fail"
            case .onAppear:    return "RestTimerSettingsView_Appear"
            case .onDisappear: return "RestTimerSettingsView_Disappear"
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
