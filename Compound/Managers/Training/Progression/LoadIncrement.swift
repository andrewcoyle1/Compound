//
//  LoadIncrement.swift
//  Compound
//
//  How big a step up in weight is, and how hard a set may be logged before it earns one. A fixed
//  2.5 kg is 2.5 % of a 100 kg squat but 21 % of a 12 kg lateral raise, so the step is a share of
//  the working weight instead, rounded to what the equipment can make. Pure, like the engine.
//
//  Sources and Compound's own choices: `MethodInfo.smartProgression`.
//

import Foundation

enum LoadIncrement {

    /// The share of the working weight to add, by exercise type: inside ACSM's 2–10 % band
    /// (ACSM 2009). Lower-body compounds 5 %, upper-body compounds 2.5 % (the low end of
    /// 2.5–5 %, so a bench press steps as it always has), isolation and core 5 % (the low end of
    /// 5–10 %). An exercise without a type steps as an upper-body compound.
    static func targetFraction(for type: ExerciseType?) -> Double {
        switch type {
        case .compoundLower:                         return 0.05
        case .compoundUpper, nil:                    return 0.025
        case .isolationUpper, .isolationLower, .core: return 0.05
        }
    }

    /// ACSM's upper bound. A smallest available step bigger than this share of the working weight
    /// is too big a jump, and the lift progresses by reps until it is not.
    static let maximumFraction = 0.10

    /// The reps-in-reserve floor a compound lift is held to when its template sets none: a logged
    /// RPE above 9.5 (under one rep in reserve, with the engine's half-point tolerance) does not
    /// earn weight. The low end of the 1–3 reps in reserve suggested for compounds; isolation and
    /// machine work may go to failure (0–2), so it gets no floor. `nil` without a type.
    static func defaultReserve(for type: ExerciseType?) -> Int? {
        switch type {
        case .compoundUpper, .compoundLower:                return 1
        case .isolationUpper, .isolationLower, .core, nil: return nil
        }
    }

    /// The reps in reserve a reset aims for when the template sets none: the middle of the 1–3
    /// suggested for compounds and the 2–3 for novices.
    static let resetReserve = 2

    /// A reset re-derives the weight from the estimated one-rep max, kept between 5 % and 15 %
    /// under the weight that was missed.
    static let resetFloorFraction = 0.85
    static let resetCeilingFraction = 0.95

    /// Without an estimate to derive it from (no weight, or more than ten reps to failure), a
    /// reset takes ten per cent off, the practitioner convention it replaces.
    static let resetFallbackFraction = 0.90

    /// A set logged at an RPE under this, below the bottom of its range, was stopped short with
    /// reps in reserve, so it is not the failure a reset answers.
    static let resetMinimumRPE = 9.5
}
