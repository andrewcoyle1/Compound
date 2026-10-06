//
//  ExerciseDefinitionRules.swift
//  Compound
//

import Foundation

/// What makes an exercise definition coherent.
///
/// `isBodyweight` means only that the exercise cannot be loaded beyond bodyweight.
/// `bodyWeightContribution` is a property of the movement — the share of bodyweight it moves — and
/// applies to any exercise: weighted pull-ups and dips, squats, Smith good mornings.
enum ExerciseDefinitionRules {

    static let contributionRange = 0...100

    /// The value the contribution field starts at when the Bodyweight toggle is on.
    static let bodyweightContributionPreset = 75

    static func isValid(contribution: Int) -> Bool {
        contributionRange.contains(contribution)
    }

    /// Metrics that record external load. Assistance is not one of them: an assisted machine is
    /// bodyweight minus assistance, so it stays a bodyweight exercise.
    static let loadedMetrics: Set<TrackableExerciseMetric> = [.weight, .weightPerSide, .weightPerSidePersistent]

    /// A bodyweight exercise cannot be loaded, so tracking a load on it contradicts the flag.
    static func bodyweightConflict(isBodyweight: Bool, metrics: [TrackableExerciseMetric]) -> Bool {
        isBodyweight && metrics.contains { loadedMetrics.contains($0) }
    }
}
