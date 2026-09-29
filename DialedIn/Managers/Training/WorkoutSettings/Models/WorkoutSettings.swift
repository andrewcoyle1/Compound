import Foundation

struct WorkoutSettings: DataSyncModelProtocol {

    var id: String = "workout_settings"
    var authorId: String

    // MARK: - General
    var previousWorkoutReference: PreviousWorkoutReferenceOption = .sameWorkout
    var propagateChanges: Bool = false
    var rirTracking: Bool = false
    var supersetAutoScroll: Bool = true
    var exerciseAutoNext: Bool = true

    // MARK: - Display
    var keepAlive: Bool = true
    var showWorkoutTimer: Bool = true
    var showBodyweightContribution: Bool = false
    
    // MARK: - Warm-Up
    var addSmartWarmUps: Bool = true

    // MARK: - Smart Progression
    var smartProgressionApplyInSession: Bool = false
    var smartProgressionInitialLogFill: InitialLogFillOption = .smartProgression
    var smartProgressionAdjustmentMode: ProgressionAdjustmentMode = .weightFirst

    // MARK: - Rest Timer: Behaviour
    var useRestTimers: Bool = true
    var restAfterLastWarmUp: Bool = true
    var restBetweenExercises: Bool = true
    var restBetweenSideSets: Bool = false

    // MARK: - Rest Timer: Notifications
    var restTimerPlaySound: Bool = true
    var restTimerVibrate: Bool = true

    // MARK: - Rest Timer: Scaling
    var warmUpRestScaling: Double = 0.75
    var betweenExercisesRestScaling: Double = 1.0
    var sideSetRestScaling: Double = 0.5

    // MARK: - Rest Timer: Durations
    /// Per-exercise-type override durations (ExerciseType.rawValue → seconds).
    var restDurationsByExerciseType: [String: Int] = [:]
    /// Global default rest duration in seconds. Used by the workout tracker.
    var defaultRestDurationSeconds: Int = 90
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case keepAlive = "keep_alive"
        case showWorkoutTimer = "show_workout_timer"
        case showBodyweightContribution = "show_bodyweight_contribution"
        case exerciseAutoNext = "exercise_auto_next"
        case propagateChanges = "propagate_changes"
        case rirTracking = "rir_tracking"
        case addSmartWarmUps = "add_smart_warm_ups"
        case supersetAutoScroll = "superset_auto_scroll"
        case useRestTimers = "use_rest_timers"
        case restAfterLastWarmUp = "rest_after_last_warm_up"
        case restBetweenExercises = "rest_between_exercises"
        case restBetweenSideSets = "rest_between_side_sets"
        case restTimerPlaySound = "rest_timer_play_sound"
        case restTimerVibrate = "rest_timer_vibrate"
        case warmUpRestScaling = "warm_up_rest_scaling"
        case betweenExercisesRestScaling = "between_exercises_rest_scaling"
        case sideSetRestScaling = "side_set_rest_scaling"
        case restDurationsByExerciseType = "rest_durations_by_exercise_type"
        case defaultRestDurationSeconds = "default_rest_duration_seconds"
        case previousWorkoutReference = "previous_workout_reference"
        case smartProgressionApplyInSession = "smart_progression_apply_in_session"
        case smartProgressionInitialLogFill = "smart_progression_initial_log_fill"
        case smartProgressionAdjustmentMode = "smart_progression_adjustment_mode"
    }
    
    var eventParameters: [String: Any] {
        [:]
    }
    
    static var mock: Self {
        WorkoutSettings(authorId: "mock_user_123")
    }
    
}

/// Which past session the tracker's "Prev" column and smart progression reason from.
///
/// The raw values are stored in Firestore, so they are load-bearing. `"anyWorkout"` has always
/// meant "the last time this workout template was done" — the title said otherwise, but the lookup
/// never left the template — so it stays bound to `.sameWorkout`. The genuinely template-free
/// scope is the new `.anyExercise`, and nobody's stored setting changes meaning.
enum PreviousWorkoutReferenceOption: String, DataSyncModelProtocol, CaseIterable {
    var id: String { self.rawValue }

    /// The last time this exercise was performed at all, whatever workout it was part of.
    case anyExercise

    /// The last completed session of this workout template, in any program. The default, and what
    /// `"anyWorkout"` has always done.
    case sameWorkout = "anyWorkout"

    /// As `.sameWorkout`, restricted to the program this workout is being done in.
    case workoutsInProgram

    var title: String {
        switch self {
        case .anyExercise:
            return String(localized: "Any workout")
        case .sameWorkout:
            return String(localized: "This workout")
        case .workoutsInProgram:
            return String(localized: "This workout within the current program")
        }
    }

    var subtitle: String {
        switch self {
        case .anyExercise:
            return String(localized: "Previous values show the weight, reps, and RIR from the last time you performed this exercise, in any workout at all.")
        case .sameWorkout:
            return String(localized: "Previous values come from the last time you completed this workout, in any program. If this workout has no history for an exercise, the last time you performed it anywhere is shown instead.")
        case .workoutsInProgram:
            return String(localized: "Previous values come from the last time you completed this workout within the current program. If there is none for an exercise, the last time you performed it anywhere is shown instead.")
        }
    }
}

enum InitialLogFillOption: String, DataSyncModelProtocol, CaseIterable {
    var id: String { self.rawValue }

    case smartProgression
    case previousValues
    case empty

    var title: String {
        switch self {
        case .smartProgression: return String(localized: "Smart Progression values")
        case .previousValues:   return String(localized: "Previous workout values")
        case .empty:            return String(localized: "Leave empty")
        }
    }

    var subtitle: String {
        switch self {
        case .smartProgression:
            return String(localized: "Prefill each set with the values Smart Progression suggests for your next session.")
        case .previousValues:
            return String(localized: "Prefill each set with exactly what you logged last time, with no progression applied.")
        case .empty:
            return String(localized: "Start every set blank and enter the values yourself.")
        }
    }
}

enum ProgressionAdjustmentMode: String, DataSyncModelProtocol, CaseIterable {
    var id: String { self.rawValue }

    case weightFirst
    case repsFirst

    var title: String {
        switch self {
        case .weightFirst: return String(localized: "Weight-first")
        case .repsFirst:   return String(localized: "Reps-first")
        }
    }

    var subtitle: String {
        switch self {
        case .weightFirst:
            return String(localized: "Add weight once you reach the top of the rep range, then reset reps to the bottom.")
        case .repsFirst:
            return String(localized: "Add reps up to the top of the range before adding any weight.")
        }
    }
}
