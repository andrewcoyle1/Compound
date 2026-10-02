import SwiftUI

@Observable
@MainActor
class ScaleWeightPresenter {
    
    private let interactor: ScaleWeightInteractor
    private let router: ScaleWeightRouter

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
        [
            TimeSeries(
                name: "Weight",
                data: weightEntries.compactMap { entry in
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
    
    init(interactor: ScaleWeightInteractor, router: ScaleWeightRouter) {
        self.interactor = interactor
        self.router = router
    }
        
    func onAddWeightPressed() {
        router.showLogWeightView()
    }
    
    func onDismissPressed() {
        router.dismissScreen()
    }
    
    /// Read live, so weigh-ins imported from Apple Health appear while the screen is open.
    private var weightEntries: [BodyMeasurementEntry] {
        interactor.bodyMeasurements.filter { $0.deletedAt == nil && $0.weightKg != nil }
    }

}

extension ScaleWeightPresenter: @MainActor MetricDetailPresenter {
    typealias Entry = BodyMeasurementEntry

    var entries: [BodyMeasurementEntry] {
        weightEntries
    }

    /// Scale weight uses the history chart (time series), not the contribution chart.
    var contributionSeries: TimeSeries? { nil }

    func displayValue(for entry: BodyMeasurementEntry) -> String {
        guard let weightKg = entry.weightKg else { return Format.placeholder }
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
            chartColor: Color.Metric.scaleWeight
        )
    }

    func onAppear() async {
        await interactor.syncWeightFromHealthKit()
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
