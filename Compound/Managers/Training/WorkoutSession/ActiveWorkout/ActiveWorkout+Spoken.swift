//
//  ActiveWorkout+Spoken.swift
//  Compound
//
//  A set as VoiceOver reads it.
//

import Foundation

extension ActiveWorkout {

    /// "100 kilograms, 8 reps", "12 reps", "1:30": a set's figures as VoiceOver reads them, units
    /// in words; `nil` while the set holds none.
    static func spokenFigures(
        of set: WorkoutSetModel,
        trackingMode: TrackingMode,
        unit: ExerciseWeightUnit,
        distanceUnit: ExerciseDistanceUnit,
        locale: Locale = .autoupdatingCurrent
    ) -> String? {
        var parts: [String] = []
        switch trackingMode {
        case .weightReps, .repsOnly:
            if trackingMode == .weightReps, let weightKg = set.loadKg, weightKg > 0 {
                parts.append(spokenWeight(kg: weightKg, unit: unit, locale: locale))
            }
            if let reps = set.reps { parts.append(Format.reps(reps, locale: locale)) }
        case .timeOnly, .distanceTime:
            if let figures = figures(of: set, trackingMode: trackingMode, unit: unit, distanceUnit: distanceUnit) {
                parts.append(figures)
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// "Set 2, next to log, 100 kilograms, 8 reps": a set row read as one VoiceOver container
    /// (a11y.md M4), so the Containers rotor moves set by set and each says where it stands.
    static func rowSpokenLabel(name: String, state: SetRowState?, figures: String?) -> String {
        let status: String? = switch state {
        case .current?: String(localized: "next to log")
        case .done?: String(localized: "logged")
        case .upcoming?: String(localized: "upcoming")
        case nil: nil
        }
        return [name, status, figures].compactMap { $0 }.joined(separator: ", ")
    }
}
