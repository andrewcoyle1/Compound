//
//  ProgressionModels.swift
//  DialedIn
//
//  The values `ProgressionEngine` reads and writes. They are deliberately free of managers,
//  `@MainActor` and `Date()`: everything the engine needs to know about the gym arrives as a
//  rounding closure and an increment, so the engine itself stays a pure function of its input.
//

import Foundation

/// One past session's contribution to an exercise's history: its completed working sets, in the
/// order they were logged.
struct ProgressionHistorySession: Equatable {
    let workingSets: [WorkoutSetModel]
}

/// Everything the engine is given to suggest one exercise's next session.
struct ProgressionInput {
    let trackingMode: TrackingMode
    /// The template's targets for this exercise, in set order. May be shorter than the history.
    let setTargets: [SetTarget]
    /// Most recent first, at most three: the deload rule needs to see two consecutive misses.
    let history: [ProgressionHistorySession]
    let adjustmentMode: ProgressionAdjustmentMode
    /// kg in, kg rounded to what this exercise's equipment and the user's unit can express out.
    let roundWeight: (Double) -> Double
    /// The smallest step the rounding above can express, in kg.
    let minimumIncrementKg: Double

    /// The two of them together, for the calls that only need to know what a weight may be.
    var rounding: ProgressionRounding {
        ProgressionRounding(round: roundWeight, minimumIncrementKg: minimumIncrementKg)
    }

    init(
        trackingMode: TrackingMode,
        setTargets: [SetTarget],
        history: [ProgressionHistorySession],
        adjustmentMode: ProgressionAdjustmentMode,
        roundWeight: @escaping (Double) -> Double,
        minimumIncrementKg: Double
    ) {
        self.trackingMode = trackingMode
        self.setTargets = setTargets
        self.history = history
        self.adjustmentMode = adjustmentMode
        self.roundWeight = roundWeight
        self.minimumIncrementKg = minimumIncrementKg
    }
}

/// What a weight is allowed to be: a rounding rule and the smallest step it can express.
struct ProgressionRounding {
    let round: (Double) -> Double
    let minimumIncrementKg: Double

    init(round: @escaping (Double) -> Double, minimumIncrementKg: Double) {
        self.round = round
        self.minimumIncrementKg = minimumIncrementKg
    }
}

/// One suggested set. Every field is optional because a suggestion only speaks about the metrics
/// its exercise is tracked by — and says nothing at all when there is no history to speak from.
struct SuggestedSet: Equatable {
    let weightKg: Double?
    let reps: Int?
    let durationSec: Int?
    let distanceMeters: Double?

    init(
        weightKg: Double? = nil,
        reps: Int? = nil,
        durationSec: Int? = nil,
        distanceMeters: Double? = nil
    ) {
        self.weightKg = weightKg
        self.reps = reps
        self.durationSec = durationSec
        self.distanceMeters = distanceMeters
    }

    /// Nothing to suggest — the caller falls back to whatever it would have done anyway.
    static let none = SuggestedSet()

    var isEmpty: Bool {
        weightKg == nil && reps == nil && durationSec == nil && distanceMeters == nil
    }
}

/// What the engine decided for one exercise, and the sets that follow from it.
struct ProgressionSuggestion: Equatable {

    /// Why the suggestion looks the way it does. The user only ever sees `hint`.
    enum Rationale: String, Equatable {
        case noHistory
        case progressWeight
        case addReps
        case hold
        case deload

        /// The one line the exercise header shows. Empty when there is nothing worth saying.
        var hint: String {
            switch self {
            case .noHistory:      return ""
            case .progressWeight: return String(localized: "Add weight")
            case .addReps:        return String(localized: "Add a rep")
            case .hold:           return String(localized: "Repeat last session")
            case .deload:         return String(localized: "Lighter this week")
            }
        }
    }

    let rationale: Rationale
    /// One per set, index-aligned with the exercise's working sets.
    let sets: [SuggestedSet]

    /// The suggestion for an exercise with nothing to progress from.
    static func noHistory(setCount: Int) -> ProgressionSuggestion {
        ProgressionSuggestion(rationale: .noHistory, sets: Array(repeating: .none, count: max(setCount, 0)))
    }
}

/// How a new session's working sets are filled in before the user touches them. Maps one-to-one
/// onto `InitialLogFillOption`, except that `.smartProgression` arrives already computed.
enum SessionPrefill {
    /// Exactly what was logged last time, with no progression applied.
    case previousValues
    /// Nothing at all: every working set starts blank.
    case empty
    /// The engine's suggestions, keyed by the exercise's `templateId`. An exercise missing from
    /// the dictionary — or carrying a `.noHistory` suggestion — falls back to `.previousValues`.
    case suggestions([String: ProgressionSuggestion])
}
