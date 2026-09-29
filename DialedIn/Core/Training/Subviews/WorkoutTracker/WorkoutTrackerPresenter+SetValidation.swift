//
//  WorkoutTrackerPresenter+SetValidation.swift
//  DialedIn
//
//  Split out of WorkoutTrackerPresenter.swift, which exceeded the 750-line file and
//  500-line type-body limits.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    func buttonColor(set: WorkoutSetModel, canComplete: Bool) -> Color {
        if set.completedAt != nil {
            return .green
        } else if canComplete {
            return .secondary
        } else {
            return .red.opacity(0.6)
        }
    }

    func canComplete(trackingMode: TrackingMode, set: WorkoutSetModel) -> Bool {
        switch trackingMode {
        case .weightReps:
            let hasValidWeight = set.weightKg == nil || set.weightKg! >= 0
            let hasValidReps = set.reps != nil && set.reps! > 0
            return hasValidWeight && hasValidReps

        case .repsOnly:
            return set.reps != nil && set.reps! > 0

        case .timeOnly:
            return set.durationSec != nil && set.durationSec! > 0

        case .distanceTime:
            let hasValidDistance = set.distanceMeters != nil && set.distanceMeters! > 0
            let hasValidTime = set.durationSec != nil && set.durationSec! > 0
            return hasValidDistance && hasValidTime
        }
    }

    func validateSetData(trackingMode: TrackingMode, set: WorkoutSetModel) -> Bool {
        switch trackingMode {
        case .weightReps:
            return validateWeightReps(set: set)
        case .repsOnly:
            return validateRepsOnly(set: set)
        case .timeOnly:
            return validateTimeOnly(set: set)
        case .distanceTime:
            return validateDistanceTime(set: set)
        }
    }

    func validateWeightReps(set: WorkoutSetModel) -> Bool {
        // Weight must be non-negative (including 0 for bodyweight exercises)
        if let weight = set.weightKg, weight < 0 {
            router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Weight must be a non-negative number"))
            return false
        }

        // Reps must be positive
        guard let reps = set.reps, reps > 0 else {
            router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Reps must be a positive number"))
            return false
        }

        return true
    }

    func validateRepsOnly(set: WorkoutSetModel) -> Bool {
        // Reps must be positive
        guard let reps = set.reps, reps > 0 else {
            router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Reps must be a positive number"))
            return false
        }

        return true
    }

    func validateTimeOnly(set: WorkoutSetModel) -> Bool {
        // Time must be positive
        guard let duration = set.durationSec, duration > 0 else {
            router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Duration must be a positive time"))
            return false
        }

        return true
    }

    func validateDistanceTime(set: WorkoutSetModel) -> Bool {
        // Distance must be positive
        guard let distance = set.distanceMeters, distance > 0 else {
            router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Distance must be a positive number"))
            return false
        }

        // Time must be positive
        guard let duration = set.durationSec, duration > 0 else {
            router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Duration must be a positive time"))
            return false
        }

        return true
    }
}
