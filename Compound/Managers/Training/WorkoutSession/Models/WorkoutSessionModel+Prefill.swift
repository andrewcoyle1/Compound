//
//  WorkoutSessionModel+Prefill.swift
//  Compound
//
//  How a new session's working sets are filled in before the user touches them.
//

import Foundation

extension SessionPrefill {

    /// Whether the working sets are filled in at all. `.empty` leaves every one of them blank.
    var fillsWorkingSets: Bool {
        switch self {
        case .empty:                        return false
        case .previousValues, .suggestions: return true
        }
    }

    /// The suggestion for one exercise, or `nil` when there is none worth applying — which
    /// includes `.noHistory`, since the engine never invents a starting weight. Looked up by
    /// `ActiveWorkout.historyKey`, so an exercise listed twice gets each appearance's own.
    func suggestion(for templateId: String, occurrence: Int = 0) -> ProgressionSuggestion? {
        guard case .suggestions(let byExercise) = self,
              let suggestion = byExercise[ActiveWorkout.historyKey(templateId: templateId, occurrence: occurrence)],
              suggestion.rationale != .noHistory else { return nil }
        return suggestion
    }
}

extension ProgressionSuggestion {

    /// The suggestion for one set, or `nil` past the end of the list.
    func set(at index: Int) -> SuggestedSet? {
        guard index >= 0, index < sets.count else { return nil }
        let suggested = sets[index]
        return suggested.isEmpty ? nil : suggested
    }
}

/// Everything one exercise's working sets are filled in from.
struct WorkingSetPrefill {
    let prefill: SessionPrefill
    let previousSets: [WorkoutSetModel]?
    let authorId: String
    let exercise: ExerciseModel
    let gymProfile: GymProfileModel?
    let unitPreferences: [String: ExerciseUnitPreference]?
    /// Which appearance of `exercise` in the workout this is, from 0 (`ActiveWorkout.historyKey`).
    var occurrence = 0

    /// Fills `workingSets` from the suggestion for this exercise, falling back per field to what
    /// was logged last time. A set with neither is left exactly as it was built.
    ///
    /// `workingSets` has one row per set, a per-side exercise included (one `both` row each). Last
    /// session may have been split into a left and a right row per set, so it is read one row per
    /// set too, the left standing for the pair — otherwise set 2 would inherit set 1's right arm.
    @MainActor
    func apply(to workingSets: inout [WorkoutSetModel]) {
        guard prefill.fillsWorkingSets else { return }

        let suggestion = prefill.suggestion(for: exercise.id, occurrence: occurrence)
        // A drop or mini-set is part of the set before it, and filled by hand when it is added:
        // matched by position, last time's drop would hand its lighter weight to the next set.
        let previousWorkingSets = (previousSets ?? []).filter { !$0.isWarmup && $0.side != .right && !$0.isSubSet }
        // The same rule the keyboard steps by, so a prefilled weight is one the gym can make.
        let rule = WeightRoundingRule(exercise: exercise, gymProfile: gymProfile, preferredWeightUnit: unitPreferences?[exercise.id]?.weightUnit)

        for (position, index) in workingSets.indices.filter({ !workingSets[$0].isSubSet }).enumerated() {
            let suggested = suggestion?.set(at: position)
            let previous = position < previousWorkingSets.count ? previousWorkingSets[position] : nil
            guard suggested != nil || previous != nil else { continue }

            let weightKg = (suggested?.weightKg ?? previous?.weightKg ?? workingSets[index].weightKg).map(rule.round)

            // Changed in place rather than rebuilt field by field, so its kind and parent survive.
            // The rows were built for `authorId` (`defaultSets`).
            workingSets[index].reps = suggested?.reps ?? previous?.reps ?? workingSets[index].reps
            workingSets[index].weightKg = weightKg
            // Bands carry no kg, so no suggestion names them: they come from last time.
            workingSets[index].bands = previous?.bands ?? workingSets[index].bands
            workingSets[index].durationSec = suggested?.durationSec ?? previous?.durationSec ?? workingSets[index].durationSec
            workingSets[index].distanceMeters = suggested?.distanceMeters ?? previous?.distanceMeters ?? workingSets[index].distanceMeters
            workingSets[index].targetReps = suggested?.targetReps ?? workingSets[index].targetReps
            workingSets[index].isWarmup = false
            workingSets[index].completedAt = nil
            workingSets[index].dateCreated = .now
        }
    }
}
