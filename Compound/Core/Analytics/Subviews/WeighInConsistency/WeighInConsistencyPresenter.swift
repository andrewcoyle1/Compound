//
//  WeighInConsistencyPresenter.swift
//  Compound
//

import SwiftUI

@Observable
@MainActor
class WeighInConsistencyPresenter {

    private let interactor: ScaleWeightInteractor
    private let router: ScaleWeightRouter
    private let calendar = Calendar.current

    private(set) var cachedEntries: [BodyMeasurementEntry] = []

    init(interactor: ScaleWeightInteractor, router: ScaleWeightRouter) {
        self.interactor = interactor
        self.router = router
        rebuildCaches()
    }

    func loadLocalWeightEntries() {
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
    }
}

extension WeighInConsistencyPresenter: @MainActor MetricDetailPresenter {
    typealias Entry = BodyMeasurementEntry

    /// Weight is stored in kilograms; the card that opens this screen converts, and this screen
    /// hardcoded " kg".
    private var weightUnit: WeightUnitPreference {
        interactor.currentUser?.submittedWeightUnitPreference ?? .kilograms
    }

    func displayValue(for entry: BodyMeasurementEntry) -> String {
        guard let weightKg = entry.weightKg else { return Format.placeholder }
        return UnitConversion.formatWeight(weightKg, unit: weightUnit)
    }

    var entries: [BodyMeasurementEntry] {
        cachedEntries
    }

    var timeSeries: [TimeSeries] {
        []
    }

    /// One point per weigh-in, over every entry there is.
    var contributionSeries: TimeSeries? {
        guard !cachedEntries.isEmpty else { return nil }
        return TimeSeries(
            name: "Weigh-Ins",
            data: cachedEntries.map { TimeSeriesDatapoint(id: $0.id, date: $0.date, value: 1) }
        )
    }

    var configuration: MetricConfiguration {
        MetricConfiguration(
            title: String(localized: "Weigh In"),
            analyticsName: "WeighInConsistencyView",
            yAxisSuffix: " \(weightUnit.abbreviation)",
            seriesNames: ["Weight"],
            showsAddButton: true,
            sectionHeader: "Weight Entries",
            emptyStateMessage: "No weigh-ins logged",
            chartColor: Color.Metric.habits,
            contributionUnit: "weigh-ins"
        )
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onAppear() async {
        loadLocalWeightEntries()
    }

    func onAddPressed() {
        onAddWeightPressed()
    }

    var supportsDeletion: Bool { true }

    func onDeleteEntry(_ entry: BodyMeasurementEntry) async {
        let updatedEntry = entry.withCleared(.weightKg)
        interactor.trackEvent(event: Event.deleteEntryStart)
        do {
            try await interactor.saveBodyMeasurement(bodyMeasurement: updatedEntry)
            interactor.trackEvent(event: Event.deleteEntrySuccess)
        } catch {
            interactor.trackEvent(event: Event.deleteEntryFail(error: error))
            // Was `try?`. The refresh below re-reads unchanged data, so a failed delete put the row
            // straight back with nothing said about why.
            router.showSimpleAlert(title: String(localized: "Unable to Delete Entry"), subtitle: String(localized: "Please try again."))
            return
        }
        rebuildCaches()
    }
}

extension WeighInConsistencyPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case deleteEntryStart
        case deleteEntrySuccess
        case deleteEntryFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear: return "WeighInConsistencyView_Appear"
            case .onDisappear: return "WeighInConsistencyView_Disappear"
            case .deleteEntryStart: return "WeighInConsistencyView_DeleteEntry_Start"
            case .deleteEntrySuccess: return "WeighInConsistencyView_DeleteEntry_Success"
            case .deleteEntryFail: return "WeighInConsistencyView_DeleteEntry_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .deleteEntryFail(let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .deleteEntryFail: return .severe
            default: return .analytic
            }
        }
    }
}
