import SwiftUI

@Observable
@MainActor
class WorkoutSettingsPresenter {

    private let interactor: WorkoutSettingsInteractor
    private let router: WorkoutSettingsRouter

    private var settings: WorkoutSettings

    init(interactor: WorkoutSettingsInteractor, router: WorkoutSettingsRouter) {
        self.interactor = interactor
        self.router = router
        self.settings = interactor.workoutSettings
    }

    /// Re-read rather than trusted from init: every screen this one pushes to edits the same
    /// settings document, and this screen stays alive underneath them. Saving a toggle writes the
    /// whole document back, so a copy taken before the user visited the rest timer would undo
    /// everything they changed there.
    func onViewAppear(delegate: WorkoutSettingsDelegate) {
        settings = interactor.workoutSettings
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: WorkoutSettingsDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onRestTimerSettingsPressed() {
        router.showRestTimerSettingsView(delegate: RestTimerSettingsDelegate())
    }

    func onSmartProgressionSettingsPressed() {
        router.showSmartProgressionSettingsView(delegate: SmartProgressionSettingsDelegate())
    }
    
    func onPreviousReferenceSettingsPressed() {
        router.showPreviousWorkoutReferenceSettingsView(delegate: PrevWORefSettingsDelegate())
    }
    
    func onExerciseAssessmentPressed() {
        router.showExerciseAssessmentView(delegate: ExerciseAssessmentDelegate())
    }
    
    // MARK: - General Settings

    var propagateChanges: Bool {
        get { settings.propagateChanges }
        set { settings.propagateChanges = newValue; save() }
    }

    var rirTracking: Bool {
        get { settings.rirTracking }
        set { settings.rirTracking = newValue; save() }
    }

    var supersetAutoScroll: Bool {
        get { settings.supersetAutoScroll }
        set { settings.supersetAutoScroll = newValue; save() }
    }

    var exerciseAutoNext: Bool {
        get { settings.exerciseAutoNext }
        set { settings.exerciseAutoNext = newValue; save() }
    }

    // MARK: - Display Settings

    var keepAlive: Bool {
        get { settings.keepAlive }
        set { settings.keepAlive = newValue; save() }
    }

    var showWorkoutTimer: Bool {
        get { settings.showWorkoutTimer }
        set { settings.showWorkoutTimer = newValue; save() }
    }

    var showBodyweightContribution: Bool {
        get { settings.showBodyweightContribution }
        set { settings.showBodyweightContribution = newValue; save() }
    }

    // MARK: - Warm-Up Settings

    var addSmartWarmUps: Bool {
        get { settings.addSmartWarmUps }
        set { settings.addSmartWarmUps = newValue; save() }
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

extension WorkoutSettingsPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: WorkoutSettingsDelegate)
        case onDisappear(delegate: WorkoutSettingsDelegate)
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .saveFail: return "WorkoutSettingsView_Save_Fail"
            case .onAppear:                 return "WorkoutSettingsView_Appear"
            case .onDisappear:              return "WorkoutSettingsView_Disappear"
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
            default:
                return .analytic
            }
        }
    }

}
