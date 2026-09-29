import SwiftUI

@Observable
@MainActor
class FavouriteMeasurementsPresenter {

    private let interactor: FavouriteMeasurementsInteractor
    private let router: FavouriteMeasurementsRouter

    private var settings: FoodLogSettings

    let allMeasurements: [String] = ["g", "oz", "ml", "cup", "tbsp", "tsp", "serving", "kcal", "kJ"]

    var favouriteMeasurements: [String] {
        settings.favouriteMeasurements
    }

    func isSelected(_ measurement: String) -> Bool {
        favouriteMeasurements.contains(measurement)
    }

    func toggleMeasurement(_ measurement: String) {
        if isSelected(measurement) {
            settings.favouriteMeasurements.removeAll { $0 == measurement }
        } else {
            settings.favouriteMeasurements.append(measurement)
        }
        save()
    }

    init(interactor: FavouriteMeasurementsInteractor, router: FavouriteMeasurementsRouter) {
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

extension FavouriteMeasurementsPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .saveFail: return "FavouriteMeasurementsView_Save_Fail"
            case .onAppear: return "FavouriteMeasurementsView_Appear"
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
