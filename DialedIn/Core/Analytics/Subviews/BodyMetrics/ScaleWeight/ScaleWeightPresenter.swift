import SwiftUI

@Observable
@MainActor
class ScaleWeightPresenter {
    
    private let interactor: ScaleWeightInteractor
    private let router: ScaleWeightRouter

    private(set) var cachedEntries: [BodyMeasurementEntry] = []
    private(set) var cachedTimeSeries: [TimeSeries] = []
    
    var currentUser: UserModel? {
        interactor.currentUser
    }

    /// Weight is stored in kilograms. The card that opens this screen converts to the user's unit;
    /// this screen hardcoded " kg", so the two disagreed for anyone set to pounds.
    private var weightUnit: WeightUnitPreference {
        interactor.currentUser?.submittedWeightUnitPreference ?? .kilograms
    }

    var weightHistory: [BodyMeasurementEntry] {
        interactor.bodyMeasurements
    }
    
    var timeSeries: [TimeSeries] {
        cachedTimeSeries
    }
    
    init(interactor: ScaleWeightInteractor, router: ScaleWeightRouter) {
        self.interactor = interactor
        self.router = router
        rebuildCaches()
    }
        
    func onAddWeightPressed() {
        router.showLogWeightView()
    }
    
    func onDismissPressed() {
        router.dismissScreen()
    }
    
    private func rebuildCaches() {
        let entries = interactor.bodyMeasurements.filter { $0.deletedAt == nil && $0.weightKg != nil }
        cachedEntries = entries
        cachedTimeSeries = [
            TimeSeries(
                name: "Weight",
                data: entries.compactMap { entry in
                    guard let weightKg = entry.weightKg else { return nil }
                    return TimeSeriesDatapoint(
                        id: entry.id,
                        date: entry.date,
                        value: UnitConversion.convertWeight(weightKg, to: weightUnit)
                    )
                }
            )
        ]
    }
}

extension ScaleWeightPresenter: @MainActor MetricDetailPresenter {
    typealias Entry = BodyMeasurementEntry

    var entries: [BodyMeasurementEntry] {
        cachedEntries
    }

    /// Scale weight uses the history chart (time series), not the contribution chart.
    var contributionSeries: TimeSeries? { nil }

    func displayValue(for entry: BodyMeasurementEntry) -> String {
        guard let weightKg = entry.weightKg else { return "--" }
        return UnitConversion.formatWeight(weightKg, unit: weightUnit)
    }

    var configuration: MetricConfiguration {
        MetricConfiguration(
            title: String(localized: "Scale Weight"),
            analyticsName: "ScaleWeightView",
            yAxisSuffix: " \(weightUnit.abbreviation)",
            seriesNames: ["Weight"],
            showsAddButton: true,
            sectionHeader: "Weight Entries",
            emptyStateMessage: "No weight entries",
            chartColor: .green
        )
    }

    func onAppear() async {
        rebuildCaches()
    }

    func onAddPressed() {
        onAddWeightPressed()
    }

    var supportsDeletion: Bool { true }

    func onDeleteEntry(_ entry: BodyMeasurementEntry) async {
        let updatedEntry = entry.withCleared(.weightKg)
        do {
            try await interactor.saveBodyMeasurement(bodyMeasurement: updatedEntry)
        } catch {
            // Was `try?`. The refresh below re-reads unchanged data, so a failed delete put the row
            // straight back with nothing said about why. The alert told the user; nothing told us,
            // so a backend outage here looked like nobody deleting anything.
            interactor.trackEvent(event: Event.deleteEntryFail(error: error))
            router.showSimpleAlert(title: String(localized: "Unable to Delete Entry"), subtitle: String(localized: "Please try again."))
            return
        }
        rebuildCaches()
    }
}

extension ScaleWeightPresenter {
    enum Event: LoggableEvent {
        case deleteEntryFail(error: Error)

        var eventName: String {
            switch self {
            case .deleteEntryFail: return "ScaleWeightView_DeleteEntry_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .deleteEntryFail(error: let error):
                return error.eventParameters
            }
        }

        var type: LogType {
            switch self {
            case .deleteEntryFail:
                return .severe
            }
        }
    }
}
