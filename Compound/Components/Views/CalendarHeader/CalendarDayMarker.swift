//
//  CalendarDayMarker.swift
//  Compound
//
//  Created by Andrew Coyle on 16/09/2026.
//

import Foundation

/// What a calendar day cell marks, supplied per day by whichever screen hosts the header.
///
/// Training counts logged sessions; Nutrition tracks calories against the day's goal, so the
/// same cell has to draw either a plain outline or a progress ring.
enum CalendarDayMarker: Hashable, Sendable {

    /// A number of logged items. Outlines the day, and badges counts above one.
    case count(Int)

    /// Logged workouts in the order they were done, each drawn as its own stroke in its
    /// mesocycle's colour (a hex string), or the accent for nil: a workout outside any mesocycle.
    case sessions(colours: [String?])

    /// Progress toward a daily goal, drawn as a ring around the cell.
    ///
    /// `grace` is how far past `goal` still counts as on target — going over by a little is not
    /// worth flagging, so the ring only reads as over once it is exceeded.
    case goalProgress(value: Double, goal: Double, grace: Double)

    /// How much of the ring is drawn, 0...1. A `count` marker is all or nothing.
    var fraction: Double {
        switch self {
        case .count(let count):
            return count > 0 ? 1 : 0
        case .sessions(let colours):
            return colours.isEmpty ? 0 : 1
        case .goalProgress(let value, let goal, _):
            guard goal > 0 else { return 0 }
            return min(max(value / goal, 0), 1)
        }
    }

    /// True once the goal has been reached, whether or not the grace allowance is also used up.
    var isGoalMet: Bool {
        switch self {
        case .count, .sessions:
            return false
        case .goalProgress(let value, let goal, _):
            return goal > 0 && value >= goal
        }
    }

    /// True once the goal plus its grace allowance has been exceeded.
    var isOverGoal: Bool {
        switch self {
        case .count, .sessions:
            return false
        case .goalProgress(let value, let goal, let grace):
            return goal > 0 && value > goal + grace
        }
    }

    /// Whether the ring should draw dashed rather than solid. Met and over-goal used to differ
    /// only by hue (green vs. red), which is invisible to colour-blind users; over-goal now also
    /// changes shape.
    var ringIsDashed: Bool {
        isOverGoal
    }

    /// Whether the day has anything on it at all.
    var isEmpty: Bool {
        switch self {
        case .count(let count):
            return count <= 0
        case .sessions(let colours):
            return colours.isEmpty
        case .goalProgress(let value, _, _):
            return value <= 0
        }
    }

    /// What VoiceOver says the day holds, or nil when it holds nothing. The ring and the badge are
    /// drawn, not text, so without this a marked day and an empty one sound the same.
    var accessibilityDescription: String? {
        guard !isEmpty else { return nil }
        switch self {
        case .count(let count):
            return count == 1 ? String(localized: "Logged") : String(localized: "\(count) logged")
        case .sessions(let colours):
            return colours.count == 1 ? String(localized: "Logged") : String(localized: "\(colours.count) logged")
        case .goalProgress(let value, let goal, _):
            guard goal > 0 else { return String(localized: "Logged") }
            let progress = String(localized: "\(Format.percent(value / goal)) of goal")
            if isOverGoal {
                return "\(progress), \(String(localized: "Over goal"))"
            }
            if isGoalMet {
                return "\(progress), \(String(localized: "Goal met"))"
            }
            return progress
        }
    }

    /// The number shown in the corner badge, if any. Progress rings and one stroke per workout
    /// speak for themselves.
    var badgeCount: Int? {
        switch self {
        case .count(let count):
            return count > 1 ? count : nil
        case .goalProgress, .sessions:
            return nil
        }
    }
}
