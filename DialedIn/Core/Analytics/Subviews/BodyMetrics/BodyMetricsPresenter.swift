import SwiftUI
import Foundation

@Observable
@MainActor
class BodyMetricsPresenter {

    private let interactor: BodyMetricsInteractor
    private let router: BodyMetricsRouter

    private var bodyMeasurements: [BodyMeasurementEntry] {
        interactor.bodyMeasurements
    }

    init(interactor: BodyMetricsInteractor, router: BodyMetricsRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onMeasurementPressed(_ type: BodyMetricType, themeColor: Color?) {
        switch type {
        case .scaleWeight:
            router.showScaleWeightView(delegate: ScaleWeightDelegate(), themeColor: themeColor)
        case .visualBodyFat:
            router.showVisualBodyFatView(delegate: VisualBodyFatDelegate(), themeColor: themeColor)
        default:
            guard let kind = type.measurementKind else { return }
            router.showBodyMeasurementDetailView(kind: kind, themeColor: themeColor)
        }
    }

    // MARK: - Ratios

    /// The two derived ratios, as cards in the same shape as the measured ones.
    ///
    /// These read as real numbers now. They previously showed "---" against a "Last 7 Entries"
    /// subtitle with no action behind them, which claimed there was a history to look at.
    var ratioCards: [BodyRatioCardModel] {
        BodyRatioKind.allCases.map { kind in
            let entries = BodyRatioPresenter.entries(
                kind: kind,
                measurements: bodyMeasurements,
                heightCentimetres: interactor.currentUser?.submittedHeightCentimeters
            )
            let recent = Array(entries.suffix(7))
            return BodyRatioCardModel(
                id: kind,
                title: kind.title,
                subtitle: recent.isEmpty ? String(localized: "No Entries") : String(localized: "Last \(recent.count) Entries"),
                latestValueText: recent.last?.displayValue ?? "--",
                sparklineData: recent.map { (date: $0.date, value: $0.ratio) }
            )
        }
    }

    func onRatioPressed(_ kind: BodyRatioKind, themeColor: Color?) {
        router.showBodyRatioView(delegate: BodyRatioDelegate(kind: kind), themeColor: themeColor)
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    func onProgressPhotosPressed() {
        router.showProgressPhotosView()
    }

    var sections: [BodyMetricsSection] {
        [
            BodyMetricsSection(
                id: "weightAndBodyFat",
                header: String(localized: "Weight & Body Fat"),
                cards: [displayModel(for: .scaleWeight), displayModel(for: .visualBodyFat)]
            ),
            BodyMetricsSection(
                id: "upperBody",
                header: String(localized: "Upper Body"),
                cards: [
                    displayModel(for: .neck),
                    displayModel(for: .shoulders),
                    displayModel(for: .bust),
                    displayModel(for: .chest),
                    displayModel(for: .waist),
                    displayModel(for: .hips)
                ]
            ),
            BodyMetricsSection(
                id: "arms",
                header: String(localized: "Arms"),
                cards: [
                    displayModel(for: .leftBicep),
                    displayModel(for: .rightBicep),
                    displayModel(for: .leftForearm),
                    displayModel(for: .rightForearm),
                    displayModel(for: .leftWrist),
                    displayModel(for: .rightWrist)
                ]
            ),
            BodyMetricsSection(
                id: "legs",
                header: String(localized: "Legs"),
                cards: [
                    displayModel(for: .leftThigh),
                    displayModel(for: .rightThigh),
                    displayModel(for: .leftCalf),
                    displayModel(for: .rightCalf),
                    displayModel(for: .leftAnkle),
                    displayModel(for: .rightAnkle)
                ]
            )
        ]
    }

    var weightUnit: WeightUnitPreference {
        interactor.currentUser?.submittedWeightUnitPreference ?? .kilograms
    }

    var lengthUnit: LengthUnitPreference {
        interactor.currentUser?.submittedLengthUnitPreference ?? .centimeters
    }

    /// Converts a stored value into what the user asked to see. Every circumference card used to
    /// print its centimetres under the label "in" — a 40 cm neck read as 40 in — and the detail
    /// screen behind the card said "cm" for the same number.
    private func display(_ value: Double, as measure: BodyMetricType.Measure) -> Double {
        switch measure {
        case .weightKilograms:   return UnitConversion.convertWeight(value, to: weightUnit)
        case .lengthCentimeters: return UnitConversion.convertLength(value, to: lengthUnit)
        case .percentage:        return value
        }
    }

    private func unitText(for measure: BodyMetricType.Measure) -> String {
        switch measure {
        case .weightKilograms:   return weightUnit.abbreviation
        case .lengthCentimeters: return lengthUnit.measurementAbbreviation
        case .percentage:        return "%"
        }
    }

    func displayModel(for type: BodyMetricType) -> BodyMetricCardModel {
        let entries = lastEntries(for: type)
        let measure = type.measure
        let data = entries.compactMap { entry -> (date: Date, value: Double)? in
            guard let value = type.value(from: entry) else { return nil }
            return (date: entry.date, value: display(value, as: measure))
        }
        let subtitle = entries.isEmpty ? String(localized: "No Entries") : String(localized: "Last 7 Entries")
        let latestValueText: String
        if let last = entries.last, let value = type.value(from: last) {
            latestValueText = display(value, as: measure).formatted(.number.precision(.fractionLength(1)))
        } else {
            latestValueText = "--"
        }
        return BodyMetricCardModel(
            id: type,
            title: type.displayTitle,
            subtitle: subtitle,
            latestValueText: latestValueText,
            unitText: unitText(for: measure),
            sparklineData: data
        )
    }

    private func lastEntries(for type: BodyMetricType) -> [BodyMeasurementEntry] {
        let filtered = bodyMeasurements.filter { entry in
            guard entry.deletedAt == nil else { return false }
            return type.value(from: entry) != nil
        }
        let sorted = filtered.sorted { $0.date < $1.date }
        return Array(sorted.suffix(7))
    }

}

extension BodyMetricsPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear:             return "BodyMetricsView_Appear"
            case .onDisappear:          return "BodyMetricsView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }
}
