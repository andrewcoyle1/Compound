import SwiftUI

@Observable
@MainActor
class SmartProgressionSettingsPresenter {
    
    private let interactor: SmartProgressionSettingsInteractor
    private let router: SmartProgressionSettingsRouter
    
    private var settings: WorkoutSettings

    init(interactor: SmartProgressionSettingsInteractor, router: SmartProgressionSettingsRouter) {
        self.interactor = interactor
        self.router = router
        self.settings = interactor.workoutSettings
    }

    let initialLogFillOptions = InitialLogFillOption.allCases
    let adjustmentModes = ProgressionAdjustmentMode.allCases

    var applyInSession: Bool {
        get { settings.smartProgressionApplyInSession }
        set { settings.smartProgressionApplyInSession = newValue; save() }
    }

    var initialLogFill: InitialLogFillOption {
        get { settings.smartProgressionInitialLogFill }
        set { settings.smartProgressionInitialLogFill = newValue; save() }
    }

    var adjustmentMode: ProgressionAdjustmentMode {
        get { settings.smartProgressionAdjustmentMode }
        set { settings.smartProgressionAdjustmentMode = newValue; save() }
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

    func onViewAppear(delegate: SmartProgressionSettingsDelegate) {
        // Every workout-settings screen edits a copy of the one settings document and writes the
        // whole thing back, so a copy taken at init and never refreshed reverts anything saved
        // elsewhere in the meantime. Re-reading here is what the sibling screens do.
        settings = interactor.workoutSettings
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: SmartProgressionSettingsDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
}

extension SmartProgressionSettingsPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: SmartProgressionSettingsDelegate)
        case onDisappear(delegate: SmartProgressionSettingsDelegate)
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .saveFail: return "SmartProgressionSettingsView_Save_Fail"
            case .onAppear:                 return "SmartProgressionSettingsView_Appear"
            case .onDisappear:              return "SmartProgressionSettingsView_Disappear"
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
