import SwiftUI

@Observable
@MainActor
class OptimisationPresenter {

    private let interactor: OptimisationInteractor
    private let router: OptimisationRouter

    private var settings: FoodLogSettings

    var quickAddEnabled: Bool {
        get { settings.quickAddEnabled }
        set { settings.quickAddEnabled = newValue; save() }
    }

    init(interactor: OptimisationInteractor, router: OptimisationRouter) {
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

extension OptimisationPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .saveFail: return "OptimisationView_Save_Fail"
            case .onAppear: return "OptimisationView_Appear"
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
