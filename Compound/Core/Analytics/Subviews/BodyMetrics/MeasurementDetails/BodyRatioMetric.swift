//
//  BodyRatioMetric.swift
//  Compound
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

/// Where a ratio falls on its screening bands. Screening, not diagnosis.
///
/// Waist to height uses NICE NG246 (2025): 0.40–0.49 healthy, 0.50–0.59 increased risk, 0.60 and
/// over high risk, for every sex and ethnicity, muscular adults included. Whether NICE sets a band
/// under 0.40 could not be confirmed, so everything under 0.50 reads as "under half your height".
/// Waist to hip uses the WHO 2008 expert consultation (published 2011): 0.90 for men and 0.85 for
/// women mark a substantially increased risk. Without a sex in the profile there is no cut-off to
/// apply, so no band.
enum BodyRatioBand: Equatable {
    case underHalfHeight, increasedRisk, highRisk
    case belowCutOff, substantiallyIncreasedRisk

    static let increasedWaistToHeight = 0.50
    static let highWaistToHeight = 0.60
    static let maleWaistToHipCutOff = 0.90
    static let femaleWaistToHipCutOff = 0.85

    static func band(kind: BodyRatioKind, ratio: Double, sex: Gender?) -> BodyRatioBand? {
        switch kind {
        case .waistToHeight:
            if ratio >= highWaistToHeight { return .highRisk }
            if ratio >= increasedWaistToHeight { return .increasedRisk }
            return .underHalfHeight
        case .waistToHip:
            guard let cutOff = waistToHipCutOff(sex: sex) else { return nil }
            return ratio >= cutOff ? .substantiallyIncreasedRisk : .belowCutOff
        }
    }

    static func waistToHipCutOff(sex: Gender?) -> Double? {
        switch sex {
        case .male: return maleWaistToHipCutOff
        case .female: return femaleWaistToHipCutOff
        case .preferNotToSay, nil: return nil
        }
    }

    var label: String {
        switch self {
        case .underHalfHeight: return String(localized: "Under half your height")
        case .increasedRisk: return String(localized: "Increased risk")
        case .highRisk: return String(localized: "High risk")
        case .belowCutOff: return String(localized: "Below the WHO cut-off")
        case .substantiallyIncreasedRisk: return String(localized: "Substantially increased risk")
        }
    }

    var isConcern: Bool {
        switch self {
        case .underHalfHeight, .belowCutOff: return false
        case .increasedRisk, .highRisk, .substantiallyIncreasedRisk: return true
        }
    }
}

extension BodyRatioKind {
    /// The bands, for the screening section's footer.
    func bandsText(sex: Gender?) -> String {
        switch self {
        case .waistToHeight:
            return String(localized: "NICE bands: 0.40–0.49 healthy, 0.50–0.59 increased risk, 0.60 or more high risk. Keep your waist to less than half your height. Screening, not diagnosis.")
        case .waistToHip:
            switch sex {
            case .male: return String(localized: "WHO cut-off for men: 0.90 or more is a substantially increased risk. Screening, not diagnosis.")
            case .female: return String(localized: "WHO cut-off for women: 0.85 or more is a substantially increased risk. Screening, not diagnosis.")
            case .preferNotToSay, nil:
                return String(localized: "WHO cut-offs: 0.90 or more for men, 0.85 or more for women, is a substantially increased risk. Set your sex in your profile to see your band. Screening, not diagnosis.")
            }
        }
    }

    var methodInfo: MethodInfo {
        switch self {
        case .waistToHeight: return .waistToHeightRatio
        case .waistToHip: return .waistToHipRatio
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

    /// Read live, so a waist logged from this screen's Add shows up without reopening it.
    var entries: [BodyRatioEntry] {
        Self.entries(
            kind: kind,
            measurements: interactor.bodyMeasurements,
            heightCentimetres: interactor.currentUser?.submittedHeightCentimeters
        )
    }

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
            chartColor: Color.Metric.measurements,
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
    }

    func onAppear() async { }

    var methodInfo: MethodInfo? { kind.methodInfo }

    /// The latest ratio and its screening band.
    var summarySection: AnyView? {
        guard let latest = entries.last else { return nil }
        let sex = interactor.currentUser?.submittedGender
        let band = BodyRatioBand.band(kind: kind, ratio: latest.ratio, sex: sex)
        return AnyView(
            Section {
                LabeledContent(String(localized: "Latest"), value: latest.displayValue)
                if let band {
                    LabeledContent(String(localized: "Screening Band")) {
                        Label(band.label, systemImage: band.isConcern ? Symbol.warning : Symbol.success)
                            .foregroundStyle(band.isConcern ? Color.warning : Color.success)
                    }
                }
            } header: {
                Text("Screening")
            } footer: {
                Text(kind.bandsText(sex: sex))
            }
        )
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear(kind: kind))
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear(kind: kind))
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

extension BodyRatioPresenter {
    enum Event: LoggableEvent {
        case onAppear(kind: BodyRatioKind)
        case onDisappear(kind: BodyRatioKind)

        var eventName: String {
            switch self {
            case .onAppear:    return "BodyRatioView_Appear"
            case .onDisappear: return "BodyRatioView_Disappear"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let kind), .onDisappear(let kind):
                return ["ratio": kind.rawValue]
            }
        }

        var type: LogType { .analytic }
    }
}

extension CoreRouter {
    func showBodyRatioView(delegate: BodyRatioDelegate, themeColor: Color? = nil) {
        router.showScreen(.push) { router in
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
