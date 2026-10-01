import SwiftUI

@Observable
@MainActor
class TimelineFoodTilesPresenter {

    private let interactor: TimelineFoodTilesInteractor
    private let router: TimelineFoodTilesRouter

    private var settings: FoodLogSettings

    var showFoodImageInTimeline: Bool {
        get { settings.showFoodImageInTimeline }
        set { settings.showFoodImageInTimeline = newValue; save() }
    }

    var showCaloriesInTimeline: Bool {
        get { settings.showCaloriesInTimeline }
        set { settings.showCaloriesInTimeline = newValue; save() }
    }

    var showMacrosInTimeline: Bool {
        get { settings.showMacrosInTimeline }
        set { settings.showMacrosInTimeline = newValue; save() }
    }

    init(interactor: TimelineFoodTilesInteractor, router: TimelineFoodTilesRouter) {
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

extension TimelineFoodTilesPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .saveFail: return "TimelineFoodTilesView_Save_Fail"
            case .onAppear: return "TimelineFoodTilesView_Appear"
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
