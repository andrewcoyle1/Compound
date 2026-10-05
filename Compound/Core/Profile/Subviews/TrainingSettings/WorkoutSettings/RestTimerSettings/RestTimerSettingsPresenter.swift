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
        Format.percent(value)
    }

    // MARK: - Scaling Pickers

    static let scalingOptions: [Double] = [0.25, 0.50, 0.75, 1.0, 1.25, 1.50, 2.0]

    enum ScalingType: String, Identifiable, CaseIterable {
        var id: String { rawValue }
        case warmUp
        case betweenExercises
        case sideSets

        /// Under the "Rest Scaling" header, so these do not repeat the toggles' titles above.
        var label: String {
            switch self {
            case .warmUp:             return String(localized: "After Warm-Ups")
            case .betweenExercises:   return String(localized: "Between Exercises")
            case .sideSets:           return String(localized: "Between Left and Right Sides")
            }
        }
    }

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
            interactor.trackEvent(event: Event.saveStart)
            do {
                try await interactor.saveWorkoutSettings(settings)
                interactor.trackEvent(event: Event.saveSuccess)
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
        case saveStart
        case saveSuccess
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .saveStart: return "RestTimerSettingsView_Save_Start"
            case .saveSuccess: return "RestTimerSettingsView_Save_Success"
            case .saveFail: return "RestTimerSettingsView_Save_Fail"
            case .onAppear:    return "RestTimerSettingsView_Appear"
            case .onDisappear: return "RestTimerSettingsView_Disappear"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .saveFail(error: let error): return error.eventParameters
            case .saveStart, .saveSuccess: return nil
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
