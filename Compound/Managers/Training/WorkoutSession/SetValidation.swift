//
//  SetValidation.swift
//  Compound
//
//  What a set needs before it can be logged. One answer for every way a set is logged: the
//  tracker's log button, a row's circle, the set keyboard and the Live Activity's Complete.
//

import Foundation

enum SetValidation {

    /// What stops `set` being logged, in the user's words, or `nil` when it can be.
    static func problem(with set: WorkoutSetModel, trackingMode: TrackingMode) -> String? {
        let noReps = String(localized: "Enter at least one rep.")
        let noTime = String(localized: "Enter a time for this set.")
        switch trackingMode {
        case .weightReps:
            if let weight = set.weightKg, weight < 0 { return String(localized: "Enter a weight of zero or more.") }
            return (set.reps ?? 0) > 0 ? nil : noReps
        case .repsOnly:
            return (set.reps ?? 0) > 0 ? nil : noReps
        case .timeOnly:
            return (set.durationSec ?? 0) > 0 ? nil : noTime
        case .distanceTime:
            guard (set.distanceMeters ?? 0) > 0 else { return String(localized: "Enter a distance for this set.") }
            return (set.durationSec ?? 0) > 0 ? nil : noTime
        }
    }

    /// Whether `set` holds what its tracking mode needs.
    static func canLog(_ set: WorkoutSetModel, trackingMode: TrackingMode) -> Bool {
        problem(with: set, trackingMode: trackingMode) == nil
    }
}
