//
//  ActiveWorkout+History.swift
//  Compound
//
//  How "last time" is keyed. A plan can list the same exercise twice in one workout (a heavy
//  6–8 set, then a 1 × 20 back-off), and each needs its own history: the nth appearance of an
//  exercise is matched to the nth appearance of it last time. And a row filled from last time's
//  figures or from smart progression's suggestion.
//

import Foundation

extension ActiveWorkout {

    /// The key last time's figures and smart progression's suggestion are kept under:
    /// `"<templateId>#<occurrence>"`, the occurrence counted from 0 in workout order.
    static func historyKey(templateId: String, occurrence: Int) -> String {
        "\(templateId)#\(occurrence)"
    }

    /// `exercise`'s key, its occurrence read from where it sits in `session`.
    static func historyKey(for exercise: WorkoutExerciseModel, in session: WorkoutSessionModel) -> String {
        historyKey(templateId: exercise.templateId, occurrence: session.occurrence(of: exercise))
    }

    // MARK: - Filling a row

    /// `set` with last time's figures for the exercise's tracking mode in place. A weighted set
    /// with no weight last time keeps its own weight; its bands are last time's.
    static func filling(_ set: WorkoutSetModel, fromPrevious prev: WorkoutSetModel, trackingMode: TrackingMode) -> WorkoutSetModel {
        var set = set
        switch trackingMode {
        case .weightReps:
            if let weight = prev.weightKg { set.weightKg = weight }
            set.bands = prev.bands
            set.reps = prev.reps
        case .repsOnly:
            set.reps = prev.reps
        case .timeOnly:
            set.durationSec = prev.durationSec
        case .distanceTime:
            set.distanceMeters = prev.distanceMeters
            set.durationSec = prev.durationSec
        }
        return set
    }

    /// `set` with a suggestion in place, leaving alone every metric it says nothing about.
    static func filling(_ set: WorkoutSetModel, from suggestion: SuggestedSet) -> WorkoutSetModel {
        var set = set
        if let weightKg = suggestion.weightKg { set.weightKg = weightKg }
        if let reps = suggestion.reps { set.reps = reps }
        if let durationSec = suggestion.durationSec { set.durationSec = durationSec }
        if let distanceMeters = suggestion.distanceMeters { set.distanceMeters = distanceMeters }
        return set
    }
}
