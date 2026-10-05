import SwiftUI

@Observable
@MainActor
class LoggerFoodTilesPresenter {

    private let interactor: LoggerFoodTilesInteractor
    private let router: LoggerFoodTilesRouter

    private var settings: FoodLogSettings

    var showFoodImageInLogger: Bool {
        get { settings.showFoodImageInLogger }
        set { settings.showFoodImageInLogger = newValue; save() }
    }

    var showCaloriesInLogger: Bool {
        get { settings.showCaloriesInLogger }
        set { settings.showCaloriesInLogger = newValue; save() }
    }

    var showMacrosInLogger: Bool {
        get { settings.showMacrosInLogger }
        set { settings.showMacrosInLogger = newValue; save() }
    }

    var showPortionInLogger: Bool {
        get { settings.showPortionInLogger }
        set { settings.showPortionInLogger = newValue; save() }
    }

    init(interactor: LoggerFoodTilesInteractor, router: LoggerFoodTilesRouter) {
        self.interactor = interactor
        self.router = router
        self.settings = interactor.foodLogSettings
    }

    private func save() {
        Task {
            interactor.trackEvent(event: Event.saveStart)
            do {
                try await interactor.saveFoodLogSettings(settings)
                interactor.trackEvent(event: Event.saveSuccess)
            } catch {
                interactor.trackEvent(event: Event.saveFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Save Settings"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    /// Re-read rather than trusting the snapshot taken at init: `save()` writes the whole
    /// `FoodLogSettings` document, so a stale copy would revert whatever a sibling screen — or the
    /// favourite food and recipe ids written from the nutrition tab — saved in the meantime.
    func onViewAppear() {
        settings = interactor.foodLogSettings
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
}

extension LoggerFoodTilesPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case saveStart
        case saveSuccess
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .saveStart: return "LoggerFoodTilesView_Save_Start"
            case .saveSuccess: return "LoggerFoodTilesView_Save_Success"
            case .saveFail: return "LoggerFoodTilesView_Save_Fail"
            case .onAppear: return "LoggerFoodTilesView_Appear"
            case .onDisappear: return "LoggerFoodTilesView_Disappear"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .saveFail(error: let error): return error.eventParameters
            default: return nil
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
