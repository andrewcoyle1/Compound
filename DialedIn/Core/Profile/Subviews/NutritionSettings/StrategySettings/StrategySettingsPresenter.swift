import SwiftUI

@Observable
@MainActor
class StrategySettingsPresenter {
    
    private let interactor: StrategySettingsInteractor
    private let router: StrategySettingsRouter
    
    private var settings: NutritionStrategySettings

    /// Presents the check-in day picker.
    var isChoosingCheckInDay: Bool = false

    init(interactor: StrategySettingsInteractor, router: StrategySettingsRouter) {
        self.interactor = interactor
        self.router = router
        self.settings = interactor.nutritionStrategySettings
    }

    var fastCheckInEnabled: Bool {
        get { settings.fastCheckIn }
        set { settings.fastCheckIn = newValue; save() }
    }

    var partialLoggingEnabled: Bool {
        get { settings.partialLoggingEnabled }
        set { settings.partialLoggingEnabled = newValue; save() }
    }

    var weighInEnabled: Bool {
        get { settings.weighInEnabled }
        set { settings.weighInEnabled = newValue; save() }
    }

    var fastingEnabled: Bool {
        get { settings.fastingEnabled }
        set { settings.fastingEnabled = newValue; save() }
    }

    var loggingBreakEnabled: Bool {
        get { settings.loggingBreakEnabled }
        set { settings.loggingBreakEnabled = newValue; save() }
    }

    var checkInWeekday: Int {
        get { settings.checkInWeekday }
        set { settings.checkInWeekday = newValue; save() }
    }

    var checkInWeekdayName: String {
        settings.checkInWeekdayName
    }

    /// `Calendar.weekdaySymbols` is Sunday-first and 0-indexed, while `weekday` components are
    /// 1-based, so the tag is the index plus one.
    var weekdayOptions: [(weekday: Int, name: String)] {
        Calendar.current.weekdaySymbols.enumerated().map { (weekday: $0.offset + 1, name: $0.element) }
    }

    private func save() {
        Task {
            do {
                try await interactor.saveNutritionStrategySettings(settings)
            } catch {
                interactor.trackEvent(event: Event.saveFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Save Settings"), subtitle: String(localized: "Please try again."))
            }
        }
    }
    
    /// Re-read rather than trusting the snapshot taken at init: `save()` writes the whole
    /// `NutritionStrategySettings` document, which the Expenditure screen edits too, so a stale
    /// copy would revert whatever was saved over there.
    func onViewAppear() {
        settings = interactor.nutritionStrategySettings
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
    
    func onEditCheckInDayPressed() {
        isChoosingCheckInDay = true
    }
    
}

extension StrategySettingsPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case saveFail(error: Error)
        
        var eventName: String {
            switch self {
            case .saveFail: return "StrategySettingsView_Save_Fail"
            case .onAppear: return "StrategySettingsView_Appear"
            case .onDisappear: return "StrategySettingsView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .saveFail(error: let error): return error.eventParameters
            default:
                return nil
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
