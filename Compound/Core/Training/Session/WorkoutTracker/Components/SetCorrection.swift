//
//  SetCorrection.swift
//  Compound
//
//  What the correction bar says about the set just logged, and what a tap on it asks for.
//

import Foundation

/// What the correction row says about the set it follows. See `WorkoutTrackerPresenter+Correction`.
struct SetCorrection: Equatable {
    let setId: String
    /// "Set 2 · 100 kg × 8".
    let title: String
    /// "Set 2 logged, 100 kilograms, 8 reps".
    let spokenLabel: String
    /// The reps buttons, for a set counted in reps.
    let correctsReps: Bool
    /// False at one rep: a set is at least one.
    let canRemoveRep: Bool
    /// The reps-in-reserve chips, with `WorkoutSettings.rirTracking` on.
    let showsRIR: Bool
    let selectedRIR: Int?
}

/// What a tap on the correction row asks for.
enum SetCorrectionAction: Equatable {
    case reps(delta: Int)
    case rir(Int)
    case undo
}
