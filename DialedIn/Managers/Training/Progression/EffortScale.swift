//
//  EffortScale.swift
//  DialedIn
//
//  The one place RPE and RIR meet. Sets are logged as RPE (`WorkoutSetModel.rpe`); targets are
//  written as reps in reserve (`SetTarget.rirTarget`). They are the same scale read from opposite
//  ends: RIR = 10 − RPE, so an RPE of 8 is 2 reps in reserve and RPE 10 is none.
//

import Foundation

enum EffortScale {

    /// The RPE chips the reps keyboard offers.
    static let rpeChoices: [Double] = [6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10]

    static func rir(fromRPE rpe: Double) -> Double { 10 - rpe }

    static func rpe(fromRIR rir: Int) -> Double { 10 - Double(rir) }
}
