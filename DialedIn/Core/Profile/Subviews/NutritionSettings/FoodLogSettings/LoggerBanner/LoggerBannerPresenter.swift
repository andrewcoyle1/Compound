import SwiftUI

@Observable
@MainActor
class LoggerBannerPresenter {

    private let interactor: LoggerBannerInteractor
    private let router: LoggerBannerRouter

    private var settings: FoodLogSettings

    var showCaloriesRing: Bool {
        get { settings.showCaloriesRing }
        set { settings.showCaloriesRing = newValue; save() }
    }

    var showProteinRing: Bool {
        get { settings.showProteinRing }
        set { settings.showProteinRing = newValue; save() }
    }

    var showFatRing: Bool {
        get { settings.showFatRing }
        set { settings.showFatRing = newValue; save() }
    }

    var showCarbsRing: Bool {
        get { settings.showCarbsRing }
        set { settings.showCarbsRing = newValue; save() }
    }

    init(interactor: LoggerBannerInteractor, router: LoggerBannerRouter) {
        self.interactor = interactor
        self.router = router
        self.settings = interactor.foodLogSettings
    }

    private func save() {
        Task {
            do {
                try await interactor.saveFoodLogSettings(settings)
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
}

extension LoggerBannerPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .saveFail: return "LoggerBannerView_Save_Fail"
            case .onAppear: return "LoggerBannerView_Appear"
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
