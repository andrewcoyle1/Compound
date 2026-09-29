//
//  BodyRatioMetric.swift
//  DialedIn
//

import SwiftUI

/// The two ratios the Body Metrics screen shows. Both are derived rather than logged, so there is
/// nothing to add or delete here — the underlying waist, hip and height entries are edited on their
/// own screens.
enum BodyRatioKind: String, CaseIterable, Identifiable {
    case waistToHeight
    case waistToHip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .waistToHeight: return String(localized: "Waist to Height")
        case .waistToHip:    return String(localized: "Waist to Hip")
        }
    }

    /// What has to be recorded before the ratio can be worked out, for the empty state.
    var requirement: String {
        switch self {
        case .waistToHeight: return String(localized: "Log a waist measurement and set your height to see this ratio.")
        case .waistToHip:    return String(localized: "Log a waist and a hip measurement on the same date to see this ratio.")
        }
    }
}

struct BodyRatioDelegate {
    let kind: BodyRatioKind
}

struct BodyRatioEntry: @MainActor MetricEntry {
    let id: String
    let date: Date
    let ratio: Double

    var displayLabel: String {
        date.formatted(.dateTime.day().month().year())
    }

    var displayValue: String {
        ratio.formatted(.number.precision(.fractionLength(2)))
    }

    var systemImageName: String {
        "divide"
    }

    func timeSeriesData() -> [MetricTimeSeriesPoint] {
        [MetricTimeSeriesPoint(seriesName: "Ratio", date: date, value: ratio)]
    }
}

@Observable
@MainActor
final class BodyRatioPresenter: @MainActor MetricDetailPresenter {
    typealias Entry = BodyRatioEntry

    private let interactor: BodyMetricsInteractor
    private let router: BodyMetricsRouter
    private let kind: BodyRatioKind

    var entries: [BodyRatioEntry]

    var timeSeries: [TimeSeries] {
        let data = entries.map { TimeSeriesDatapoint(id: $0.id, date: $0.date, value: $0.ratio) }
        return [TimeSeries(name: "Ratio", data: data)]
    }

    var configuration: MetricConfiguration {
        MetricConfiguration(
            title: kind.title,
            analyticsName: "BodyRatioView_\(kind.rawValue)",
            yAxisSuffix: "",
            seriesNames: ["Ratio"],
            // Derived from other metrics — there is nothing to add or delete on this screen.
            showsAddButton: true,
            sectionHeader: "Entries",
            emptyStateMessage: kind.requirement,
            chartColor: .green,
            addActionTitle: "Log Waist",
            addActionSystemImage: "plus"
        )
    }

    init(
        interactor: BodyMetricsInteractor,
        router: BodyMetricsRouter,
        kind: BodyRatioKind
    ) {
        self.interactor = interactor
        self.router = router
        self.kind = kind
        self.entries = []
    }

    func onAppear() async {
        entries = Self.entries(
            kind: kind,
            measurements: interactor.bodyMeasurements,
            heightCentimetres: interactor.currentUser?.submittedHeightCentimeters
        )
    }

    /// A ratio is computed rather than logged, but the waist is the input measurement both kinds
    /// need, and `kind.requirement` already tells the user to log one — so this does it.
    func onAddPressed() {
        router.showLogMeasurementView(kind: .waist)
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    /// Circumferences and height are both stored in centimetres, so neither ratio needs a
    /// conversion.
    ///
    /// This used to read the waist as inches and multiply by 2.54 before dividing by a height in
    /// centimetres, making every waist-to-height ratio 2.54x too large — an 80cm waist at 180cm tall
    /// came out as 1.13 rather than 0.44, on either side of the 0.5 threshold the ratio exists for.
    static func entries(
        kind: BodyRatioKind,
        measurements: [BodyMeasurementEntry],
        heightCentimetres: Double?
    ) -> [BodyRatioEntry] {
        measurements
            .filter { $0.deletedAt == nil }
            .compactMap { entry -> BodyRatioEntry? in
                guard let waistCentimetres = entry.waistCircumference, waistCentimetres > 0 else { return nil }

                let ratio: Double
                switch kind {
                case .waistToHeight:
                    guard let heightCentimetres, heightCentimetres > 0 else { return nil }
                    ratio = waistCentimetres / heightCentimetres
                case .waistToHip:
                    // Same entry on both sides: a waist from today over a hip from last month is
                    // not a ratio of anything.
                    guard let hipCentimetres = entry.hipCircumference, hipCentimetres > 0 else { return nil }
                    ratio = waistCentimetres / hipCentimetres
                }

                return BodyRatioEntry(id: entry.id, date: entry.date, ratio: ratio)
            }
            .sorted { $0.date < $1.date }
    }

}

extension CoreRouter {
    func showBodyRatioView(delegate: BodyRatioDelegate, themeColor: Color? = nil) {
        router.showScreen(.sheet) { router in
            builder.bodyRatioView(router: router, delegate: delegate, themeColor: themeColor)
        }
    }
}

extension CoreBuilder {
    func bodyRatioView(router: AnyRouter, delegate: BodyRatioDelegate, themeColor: Color? = nil) -> some View {
        MetricDetailView(
            presenter: BodyRatioPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                kind: delegate.kind
            ),
            themeColor: themeColor
        )
    }
}
