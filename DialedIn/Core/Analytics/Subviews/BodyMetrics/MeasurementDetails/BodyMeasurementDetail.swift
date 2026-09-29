//
//  BodyMeasurementDetail.swift
//  DialedIn
//
//  Created by Andrew Coyle on 21/09/2026.
//

import SwiftUI

/// One circumference reading, as the detail screen's chart and rows show it.
///
/// Values arrive here already converted to the user's unit, so `displayValue`, the chart and the
/// suffix in `configuration` all agree.
struct BodyMeasurementDetailEntry: @MainActor MetricEntry {
    let id: String
    let date: Date
    let value: Double
    let kind: BodyMeasurementKind

    var displayLabel: String {
        "\(date.formatted(.dateTime.day().month().year()))"
    }

    var displayValue: String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    var systemImageName: String { kind.systemImageName }

    func timeSeriesData() -> [MetricTimeSeriesPoint] {
        [MetricTimeSeriesPoint(seriesName: kind.displayName, date: date, value: value)]
    }
}

/// The detail screen for any circumference measurement.
///
/// This replaced eighteen copied presenters that differed only by name, SF Symbol and which field
/// of `BodyMeasurementEntry` they read and cleared — all of which `BodyMeasurementKind` now holds.
@Observable
@MainActor
final class BodyMeasurementDetailPresenter: @MainActor MetricDetailPresenter {
    typealias Entry = BodyMeasurementDetailEntry

    private let interactor: BodyMetricsInteractor
    private let router: BodyMetricsRouter
    private let kind: BodyMeasurementKind

    var entries: [BodyMeasurementDetailEntry]

    var timeSeries: [TimeSeries] {
        let data = entries.map { TimeSeriesDatapoint(id: $0.id, date: $0.date, value: $0.value) }
        return [TimeSeries(name: kind.seriesName, data: data)]
    }

    var configuration: MetricConfiguration {
        MetricConfiguration(
            title: kind.seriesName,
            analyticsName: kind.detailAnalyticsName,
            yAxisSuffix: " \(interactor.lengthUnitPreference.measurementAbbreviation)",
            seriesNames: [kind.seriesName],
            showsAddButton: true,
            sectionHeader: "Entries",
            emptyStateMessage: kind.emptyStateMessage,
            chartColor: .green
        )
    }

    init(
        kind: BodyMeasurementKind,
        interactor: BodyMetricsInteractor,
        router: BodyMetricsRouter,
        entries: [BodyMeasurementDetailEntry] = []
    ) {
        self.kind = kind
        self.interactor = interactor
        self.router = router
        self.entries = entries.sorted { $0.date < $1.date }
    }

    func onAppear() async {
        reload()
    }

    func onAddPressed() {
        router.showLogMeasurementView(kind: kind)
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    var supportsDeletion: Bool { true }

    func onDeleteEntry(_ entry: BodyMeasurementDetailEntry) async {
        guard let baseEntry = interactor.bodyMeasurements.first(where: { $0.id == entry.id }) else { return }
        let updatedEntry = baseEntry.withCleared(kind.clearedField)
        do {
            try await interactor.saveBodyMeasurement(bodyMeasurement: updatedEntry)
        } catch {
            // Was `try?`. The refresh below re-reads unchanged data, so a failed delete put the row
            // straight back with nothing said about why.
            router.showSimpleAlert(title: String(localized: "Unable to Delete Entry"), subtitle: String(localized: "Please try again."))
            return
        }
        reload()
    }

    /// Values are converted here, once, so `displayValue` and the chart agree with the
    /// suffix in `configuration`.
    private func reload() {
        let unit = interactor.lengthUnitPreference
        entries = interactor.bodyMeasurements
            .filter { $0.deletedAt == nil }
            .compactMap { entry in
                guard let value = entry[keyPath: kind.entryValue] else { return nil }
                return BodyMeasurementDetailEntry(
                    id: entry.id,
                    date: entry.date,
                    value: UnitConversion.convertLength(value, to: unit),
                    kind: kind
                )
            }
            .sorted { $0.date < $1.date }
    }
}

extension CoreBuilder {
    func bodyMeasurementDetailView(router: AnyRouter, kind: BodyMeasurementKind, themeColor: Color? = nil) -> some View {
        MetricDetailView(
            presenter: BodyMeasurementDetailPresenter(
                kind: kind,
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            themeColor: themeColor
        )
    }
}

extension CoreRouter {
    func showBodyMeasurementDetailView(kind: BodyMeasurementKind, themeColor: Color? = nil) {
        router.showScreen(.sheet) { router in
            builder.bodyMeasurementDetailView(router: router, kind: kind, themeColor: themeColor)
        }
    }
}
