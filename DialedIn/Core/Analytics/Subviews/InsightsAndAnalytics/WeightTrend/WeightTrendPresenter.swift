//
//  WeightTrendPresenter.swift
//  DialedIn
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

@Observable
@MainActor
class WeightTrendPresenter {

    private let interactor: WeightTrendInteractor
    private let router: WeightTrendRouter

    private(set) var cachedTrendEntries: [WeightTrendEntry] = []
    private(set) var cachedTimeSeries: [TimeSeries] = []

    var currentUser: UserModel? {
        interactor.currentUser
    }

    init(interactor: WeightTrendInteractor, router: WeightTrendRouter) {
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

        let scaleData = entries.compactMap { entry -> TimeSeriesDatapoint? in
            guard let weightKg = entry.weightKg else { return nil }
            return TimeSeriesDatapoint(id: entry.id, date: entry.date, value: weightKg)
        }

        let sortedEntries = entries.sorted { $0.date < $1.date }
        let sortedPairs = sortedEntries.compactMap { entry -> (date: Date, value: Double)? in
            guard let weightKg = entry.weightKg else { return nil }
            return (date: entry.date, value: weightKg)
        }

        let trendPairs = WeightTrendCalculator.exponentialMovingAverage(data: sortedPairs)

        cachedTrendEntries = zip(sortedEntries, trendPairs).map { entry, pair in
            WeightTrendEntry(id: entry.id, date: pair.date, trendValue: pair.value)
        }

        var series: [TimeSeries] = [
            TimeSeries(name: "Scale Weight", data: scaleData)
        ]

        if trendPairs.count >= 2 {
            let trendData = trendPairs.map { pair in
                TimeSeriesDatapoint(id: "trend-\(pair.date.timeIntervalSince1970)", date: pair.date, value: pair.value)
            }
            series.append(TimeSeries(name: "Trend Weight", data: trendData))
        }

        cachedTimeSeries = series
    }
}

extension WeightTrendPresenter: @MainActor MetricDetailPresenter {
    typealias Entry = WeightTrendEntry

    var entries: [WeightTrendEntry] {
        cachedTrendEntries
    }

    var timeSeries: [TimeSeries] {
        cachedTimeSeries
    }

    /// Weight is stored in kilograms. The smoothing runs in kilograms and converts afterwards —
    /// the conversion is linear, so it is the same curve.
    private var weightUnit: WeightUnitPreference {
        interactor.currentUser?.submittedWeightUnitPreference ?? .kilograms
    }

    func displayValue(for entry: WeightTrendEntry) -> String {
        UnitConversion.formatWeight(entry.trendValue, unit: weightUnit)
    }

    var configuration: MetricConfiguration {
        MetricConfiguration(
            title: String(localized: "Weight Trend"),
            analyticsName: "WeightTrendView",
            yAxisSuffix: " \(weightUnit.abbreviation)",
            seriesNames: ["Scale Weight", "Trend Weight"],
            showsAddButton: true,
            sectionHeader: "Trend History",
            emptyStateMessage: "No weight entries",
            chartColor: nil
        )
    }

    /// Was a no-op. `rebuildCaches()` runs in `init`, so the screen had data — but it never picked
    /// up a weight logged through its own "Add" button, which routes to LogWeight and comes back.
    func onAppear() async {
        rebuildCaches()
    }

    func onAddPressed() {
        onAddWeightPressed()
    }

    var supportsDeletion: Bool { true }

    func onDeleteEntry(_ entry: WeightTrendEntry) async {
        guard let bodyEntry = interactor.bodyMeasurements.first(where: { $0.id == entry.id }) else { return }
        let updatedEntry = bodyEntry.withCleared(.weightKg)
        do {
            try await interactor.saveBodyMeasurement(bodyMeasurement: updatedEntry)
        } catch {
            // Was `try?`. The refresh below re-reads unchanged data, so a failed delete put the row
            // straight back with nothing said about why.
            router.showSimpleAlert(title: String(localized: "Unable to Delete Entry"), subtitle: String(localized: "Please try again."))
            return
        }
        rebuildCaches()
    }
}
