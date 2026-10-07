//
//  WorkoutActivityAttributes.swift
//  Compound
//
//  Created by Andrew Coyle on 30/09/2025.
//

import Foundation
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit

struct WorkoutActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        // Whether the workout timer is actively running (not paused)
        var isActive: Bool
        // Overall set progress across all exercises
        var completedSetsCount: Int
        var totalSetsCount: Int
        // Current exercise context
        var currentExerciseName: String?
        var currentExerciseImageName: String?
        var currentExerciseIndex: Int
        var totalExercisesCount: Int
        // Per-exercise set counts, within the group the target set belongs to: warm-ups while a
        // warm-up is next, working sets after that. "Warmup 1 of 2", then "Set 1 of 4".
        var currentExerciseCompletedSetsCount: Int
        var currentExerciseTotalSetsCount: Int
        var targetIsWarmup: Bool = false
        // Current set target values (for widget display and completion)
        var targetSetId: String?
        var targetWeightKg: Double?
        var targetReps: Int?
        var targetDistanceMeters: Double?
        var targetDurationSec: Int?
        // The unit the current exercise's weights are shown in, from its unit preference
        var weightUnit: LiveActivityWeightUnit = .kilograms
        // If resting, the time when the rest period ends
        var restEndsAt: Date?
        // Convenience progress value 0.0...1.0 (completedSets/totalSets)
        var progress: Double
        // Workout ended state
        var isWorkoutEnded: Bool
        // Final summary metrics (populated when workout ends successfully)
        var finalDurationSeconds: TimeInterval?
        var finalVolumeKg: Double?
        var finalCompletedSetsCount: Int?
        // Button loading state
        var isProcessingIntent: Bool
        // Workout completion state
        var isAllSetsComplete: Bool
        // The set most recently logged, whose reps can be corrected during the rest that follows
        var lastLoggedSetId: String?
        var lastLoggedReps: Int?
        var lastLoggedWeightKg: Double?
        // True when the set just logged was the last of its exercise, so the rest leads into a
        // different exercise from the one the set belonged to
        var restLeadsToNewExercise: Bool = false
        // The unit the current exercise's distances are shown in. Optional so a state encoded
        // before it existed still decodes; nil reads as metres.
        var distanceUnit: LiveActivityDistanceUnit?
        // "L" or "R" when the target set is one side of a split pair, so it reads "Set 1L"
        var targetSide: String?
        // Whether the target set holds what its tracking mode needs. Complete is disabled
        // otherwise: the app would refuse it.
        var canComplete: Bool = true
    }

    // Immutable attributes for this workout Live Activity instance
    var sessionId: String
    var workoutName: String
}
#endif
