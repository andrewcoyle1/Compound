import SwiftUI

@Observable
@MainActor
class PrevWORefSettingsPresenter {
    
    private let interactor: PrevWORefSettingsInteractor
    private let router: PreviousWorkoutReferenceSettingsRouter

    private var settings: WorkoutSettings

    init(interactor: PrevWORefSettingsInteractor, router: PreviousWorkoutReferenceSettingsRouter) {
        self.interactor = interactor
        self.router = router
        self.settings = interactor.workoutSettings
    }

    let options = PreviousWorkoutReferenceOption.allCases

    var previousWorkoutReference: PreviousWorkoutReferenceOption {
        get { settings.previousWorkoutReference }
        set { settings.previousWorkoutReference = newValue; save() }
    }

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

    /// Re-read rather than trusting the snapshot taken at init: `save()` writes the whole
    /// `WorkoutSettings` document back, so a stale copy would revert anything another screen
    /// changed in the meantime.
    func onViewAppear(delegate: PrevWORefSettingsDelegate) {
        settings = interactor.workoutSettings
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: PrevWORefSettingsDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
}

extension PrevWORefSettingsPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: PrevWORefSettingsDelegate)
        case onDisappear(delegate: PrevWORefSettingsDelegate)
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .saveFail: return "PreviousWorkoutReferenceSettingsView_Save_Fail"
            case .onAppear:                 return "PreviousWorkoutReferenceSettingsView_Appear"
            case .onDisappear:              return "PreviousWorkoutReferenceSettingsView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .saveFail(error: let error): return error.eventParameters
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
//            default:
//                return nil
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
