//
//  IdleWorkoutReminder.swift
//  Compound
//
//  "Still training?": a workout left running long after its last set pollutes its duration, the
//  calories sent to Apple Health and the battery (edges.md §4, "4-hour workout").
//

import Foundation

enum IdleWorkoutReminder {

    /// How long after the last logged set a workout counts as forgotten.
    static let threshold: TimeInterval = 60 * 60

    static func isIdle(lastActivity: Date, now: Date, threshold: TimeInterval = threshold) -> Bool {
        now.timeIntervalSince(lastActivity) >= threshold
    }
}
