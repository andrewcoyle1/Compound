import SwiftUI
import Foundation

enum BodyMetricType: Hashable {
    case scaleWeight
    case visualBodyFat
    case neck
    case shoulders
    case bust
    case chest
    case waist
    case hips
    case leftBicep
    case rightBicep
    case leftForearm
    case rightForearm
    case leftWrist
    case rightWrist
    case leftThigh
    case rightThigh
    case leftCalf
    case rightCalf
    case leftAnkle
    case rightAnkle
}

@MainActor
extension BodyMetricType {

    func value(from entry: BodyMeasurementEntry) -> Double? {
        switch self {
        case .scaleWeight: return entry.weightKg
        case .visualBodyFat: return entry.bodyFatPercentage
        default: return measurementKind.map { entry[keyPath: $0.entryValue] } ?? nil
        }
    }

    var displayTitle: String {
        switch self {
        case .scaleWeight: return String(localized: "Scale Weight")
        case .visualBodyFat: return String(localized: "Visual Body Fat")
        default: return measurementKind?.displayName ?? ""
        }
    }

    /// What the stored number means, so display code knows which conversion to apply. Storage is
    /// kilograms for weight and centimetres for every circumference.
    enum Measure {
        case weightKilograms
        case lengthCentimeters
        case percentage
    }

    var measure: Measure {
        switch self {
        case .scaleWeight:   return .weightKilograms
        case .visualBodyFat: return .percentage
        default:             return .lengthCentimeters
        }
    }

    /// The circumference this metric is, when it is one. `scaleWeight` and `visualBodyFat` are
    /// not circumferences and have no kind.
    var measurementKind: BodyMeasurementKind? {
        switch self {
        case .scaleWeight, .visualBodyFat: return nil
        case .neck: return .neck
        case .shoulders: return .shoulders
        case .bust: return .bust
        case .chest: return .chest
        case .waist: return .waist
        case .hips: return .hips
        case .leftBicep: return .leftBicep
        case .rightBicep: return .rightBicep
        case .leftForearm: return .leftForearm
        case .rightForearm: return .rightForearm
        case .leftWrist: return .leftWrist
        case .rightWrist: return .rightWrist
        case .leftThigh: return .leftThigh
        case .rightThigh: return .rightThigh
        case .leftCalf: return .leftCalf
        case .rightCalf: return .rightCalf
        case .leftAnkle: return .leftAnkle
        case .rightAnkle: return .rightAnkle
        }
    }

}

struct BodyMetricCardModel: Identifiable {
    let id: BodyMetricType
    let title: String
    let subtitle: String
    let latestValueText: String
    let unitText: String
    let sparklineData: [(date: Date, value: Double)]
}

/// A derived ratio card. Separate from `BodyMetricCardModel` because a ratio has no unit to print
/// and is keyed by `BodyRatioKind` rather than `BodyMetricType`.
struct BodyRatioCardModel: Identifiable {
    let id: BodyRatioKind
    let title: String
    let subtitle: String
    let latestValueText: String
    let sparklineData: [(date: Date, value: Double)]
}

struct BodyMetricsSection: Identifiable {
    let id: String
    let header: String
    let cards: [BodyMetricCardModel]
}
