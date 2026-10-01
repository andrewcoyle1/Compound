//
//  ProgressionSuggestionDisplay.swift
//  Compound
//
//  How a suggestion reaches the tracker's Auto column: which suggested set belongs to a row, and
//  the one line that row shows. Both are plain functions of their input so the view body stays a
//  view body — and so they can be tested without a screen.
//

import Foundation

extension SuggestedSet {

    /// The Auto column's label for this suggestion, in the exercise's tracking mode and the units
    /// the user reads that exercise in. Deliberately the same shape as the Prev column, so the two
    /// can be compared at a glance by toggling the header.
    ///
    /// `nil` when the suggestion says nothing about the metrics this mode is tracked by — the
    /// caller then falls back to the rep range.
    func label(
        trackingMode: TrackingMode,
        weightUnit: ExerciseWeightUnit,
        distanceUnit: ExerciseDistanceUnit
    ) -> String? {
        switch trackingMode {
        case .weightReps:
            guard let weightKg, let reps else { return nil }
            return "\(UnitConversion.formatWeight(weightKg, unit: weightUnit)) × \(reps)"
        case .repsOnly:
            guard let reps else { return nil }
            return "\(reps)"
        case .timeOnly:
            guard let durationSec else { return nil }
            return Self.formattedDuration(durationSec)
        case .distanceTime:
            guard let distanceMeters, let durationSec else { return nil }
            let distance = UnitConversion.formatDistance(distanceMeters, unit: distanceUnit)
            return "\(distance) \(Self.formattedDuration(durationSec))"
        }
    }

    /// m:ss, matching how the previous session's time is shown.
    static func formattedDuration(_ seconds: Int) -> String {
        "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

extension ProgressionSuggestion {

    /// The suggestion for one row of an exercise, or `nil` when there is none for it.
    ///
    /// Rows are matched by the number they are labelled with rather than their position, so both
    /// halves of a left/right pair read the one suggestion they share — a suggestion describes a
    /// set, and a left and a right are the one set. Warm-ups are never suggested for.
    func suggestedSet(for set: WorkoutSetModel, in exercise: WorkoutExerciseModel) -> SuggestedSet? {
        guard !set.isWarmup else { return nil }
        return self.set(at: exercise.workingSetNumber(for: set) - 1)
    }
}
