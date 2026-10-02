//
//  BodyMeasurementKind.swift
//  Compound
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Foundation

/// The circumference measurements the user can log, and everything that differs between them.
///
/// These eighteen used to be eighteen copied VIPER modules under `LogMeasurement/` — ~4,700 lines
/// whose only differences were the six values below. They are one module now; this is its table.
enum BodyMeasurementKind: String, CaseIterable, Identifiable, Sendable {
    case neck, shoulders, bust, chest, waist, hips
    case leftBicep, rightBicep
    case leftForearm, rightForearm
    case leftWrist, rightWrist
    case leftThigh, rightThigh
    case leftCalf, rightCalf
    case leftAnkle, rightAnkle

    var id: String { rawValue }

    /// "Left Bicep" — the noun the title, picker label and section header are all built from.
    var displayName: String { spec.displayName }

    var navigationTitle: String { "Log \(displayName) Measurement" }

    var fieldLabel: String { "\(displayName) Circumference" }

    var centimetreRange: ClosedRange<Int> { spec.centimetres }

    var inchRange: ClosedRange<Int> { spec.inches }

    var defaultCentimetres: Int { spec.defaultCentimetres }

    var defaultInches: Int { spec.defaultInches }

    /// Reads this measurement off a stored entry.
    var entryValue: KeyPath<BodyMeasurementEntry, Double?> { spec.keyPath }

    /// Writes this measurement onto an entry, via `BodyMeasurementEntry.withUpdated(_:)`.
    func update(to centimetres: Double) -> BodyMeasurementEntry.CircumferenceUpdate {
        spec.update(centimetres)
    }

    /// Clears this measurement off an entry, via `BodyMeasurementEntry.withCleared(_:)`.
    var clearedField: BodyMeasurementEntry.ClearedField { spec.cleared }

    /// The lower body is drawn walking, everything else with open arms. This was a per-screen
    /// string on all eighteen detail screens, but only ever held these two values.
    var systemImageName: String {
        switch self {
        case .leftThigh, .rightThigh, .leftCalf, .rightCalf, .leftAnkle, .rightAnkle:
            return "figure.walk"
        default:
            return "figure.arms.open"
        }
    }

    /// "Waist Circumference" — the chart series, section title and metric title all use this.
    var seriesName: String { fieldLabel }

    /// "No left bicep measurement entries"
    var emptyStateMessage: String { "No \(displayName.lowercased()) measurement entries" }

    /// The analytics screen name the per-measurement detail screens used to declare individually.
    var detailAnalyticsName: String { "\(displayName.replacingOccurrences(of: " ", with: ""))MeasurementView" }

    // MARK: - Table

    private struct Spec {
        let displayName: String
        let centimetres: ClosedRange<Int>
        let inches: ClosedRange<Int>
        let defaultCentimetres: Int
        let defaultInches: Int
        let keyPath: KeyPath<BodyMeasurementEntry, Double?>
        let update: (Double) -> BodyMeasurementEntry.CircumferenceUpdate
        let cleared: BodyMeasurementEntry.ClearedField
    }

    private var spec: Spec {
        switch self {
        case .neck: return Spec(displayName: "Neck", centimetres: 10...60, inches: 4...24, defaultCentimetres: 40, defaultInches: 16, keyPath: \.neckCircumference, update: { .neck($0) }, cleared: .neckCircumference)
        case .shoulders: return Spec(displayName: "Shoulders", centimetres: 80...150, inches: 32...60, defaultCentimetres: 115, defaultInches: 45, keyPath: \.shoulderCircumference, update: { .shoulder($0) }, cleared: .shoulderCircumference)
        case .bust: return Spec(displayName: "Bust", centimetres: 70...130, inches: 28...52, defaultCentimetres: 95, defaultInches: 37, keyPath: \.bustCircumference, update: { .bust($0) }, cleared: .bustCircumference)
        case .chest: return Spec(displayName: "Chest", centimetres: 80...140, inches: 32...56, defaultCentimetres: 105, defaultInches: 41, keyPath: \.chestCircumference, update: { .chest($0) }, cleared: .chestCircumference)
        case .waist: return Spec(displayName: "Waist", centimetres: 60...120, inches: 24...48, defaultCentimetres: 80, defaultInches: 32, keyPath: \.waistCircumference, update: { .waist($0) }, cleared: .waistCircumference)
        case .hips: return Spec(displayName: "Hips", centimetres: 80...130, inches: 32...52, defaultCentimetres: 95, defaultInches: 37, keyPath: \.hipCircumference, update: { .hip($0) }, cleared: .hipCircumference)
        case .leftBicep: return Spec(displayName: "Left Bicep", centimetres: 25...50, inches: 10...20, defaultCentimetres: 35, defaultInches: 14, keyPath: \.leftBicepCircumference, update: { .leftBicep($0) }, cleared: .leftBicepCircumference)
        case .rightBicep: return Spec(displayName: "Right Bicep", centimetres: 25...50, inches: 10...20, defaultCentimetres: 35, defaultInches: 14, keyPath: \.rightBicepCircumference, update: { .rightBicep($0) }, cleared: .rightBicepCircumference)
        case .leftForearm: return Spec(displayName: "Left Forearm", centimetres: 20...40, inches: 8...16, defaultCentimetres: 30, defaultInches: 12, keyPath: \.leftForearmCircumference, update: { .leftForearm($0) }, cleared: .leftForearmCircumference)
        case .rightForearm: return Spec(displayName: "Right Forearm", centimetres: 20...40, inches: 8...16, defaultCentimetres: 30, defaultInches: 12, keyPath: \.rightForearmCircumference, update: { .rightForearm($0) }, cleared: .rightForearmCircumference)
        case .leftWrist: return Spec(displayName: "Left Wrist", centimetres: 15...25, inches: 6...10, defaultCentimetres: 18, defaultInches: 7, keyPath: \.leftWristCircumference, update: { .leftWrist($0) }, cleared: .leftWristCircumference)
        case .rightWrist: return Spec(displayName: "Right Wrist", centimetres: 15...25, inches: 6...10, defaultCentimetres: 18, defaultInches: 7, keyPath: \.rightWristCircumference, update: { .rightWrist($0) }, cleared: .rightWristCircumference)
        case .leftThigh: return Spec(displayName: "Left Thigh", centimetres: 45...80, inches: 18...32, defaultCentimetres: 60, defaultInches: 24, keyPath: \.leftThighCircumference, update: { .leftThigh($0) }, cleared: .leftThighCircumference)
        case .rightThigh: return Spec(displayName: "Right Thigh", centimetres: 45...80, inches: 18...32, defaultCentimetres: 60, defaultInches: 24, keyPath: \.rightThighCircumference, update: { .rightThigh($0) }, cleared: .rightThighCircumference)
        case .leftCalf: return Spec(displayName: "Left Calf", centimetres: 30...50, inches: 12...20, defaultCentimetres: 38, defaultInches: 15, keyPath: \.leftCalfCircumference, update: { .leftCalf($0) }, cleared: .leftCalfCircumference)
        case .rightCalf: return Spec(displayName: "Right Calf", centimetres: 30...50, inches: 12...20, defaultCentimetres: 38, defaultInches: 15, keyPath: \.rightCalfCircumference, update: { .rightCalf($0) }, cleared: .rightCalfCircumference)
        case .leftAnkle: return Spec(displayName: "Left Ankle", centimetres: 18...30, inches: 7...12, defaultCentimetres: 22, defaultInches: 9, keyPath: \.leftAnkleCircumference, update: { .leftAnkle($0) }, cleared: .leftAnkleCircumference)
        case .rightAnkle: return Spec(displayName: "Right Ankle", centimetres: 18...30, inches: 7...12, defaultCentimetres: 22, defaultInches: 9, keyPath: \.rightAnkleCircumference, update: { .rightAnkle($0) }, cleared: .rightAnkleCircumference)
        }
    }
}
