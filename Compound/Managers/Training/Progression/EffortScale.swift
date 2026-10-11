//
//  EffortScale.swift
//  Compound
//
//  The one place RPE and RIR meet. Sets are logged as RPE (`WorkoutSetModel.rpe`); targets are
//  written as reps in reserve (`SetTarget.rirTarget`). They are the same scale read from opposite
//  ends: RIR = 10 − RPE, so an RPE of 8 is 2 reps in reserve and RPE 10 is none.
//

import Foundation

enum EffortScale {

    /// The reps in reserve a target or a logged set can name: none to six or more. Six or more is
    /// stored as six, an RPE of 4.
    static let rirChoices = Array(0...6)

    /// "2", or "6+" for the last choice.
    static func rirText(_ rir: Int) -> String {
        rir >= rirChoices.last ?? 6 ? "\(rirChoices.last ?? 6)+" : "\(rir)"
    }

    /// The reps in reserve a logged RPE reads as, to the nearest whole rep, at most six.
    static func rirChoice(fromRPE rpe: Double) -> Int {
        min(max(Int(rir(fromRPE: rpe).rounded()), 0), rirChoices.last ?? 6)
    }

    static func rir(fromRPE rpe: Double) -> Double { 10 - rpe }

    static func rpe(fromRIR rir: Int) -> Double { 10 - Double(rir) }
}
