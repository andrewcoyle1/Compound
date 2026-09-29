//
//  SetSide.swift
//  DialedIn
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Foundation

/// Which side of the body a set was performed on.
///
/// Only set for exercises worked one limb at a time — a single-arm row is two efforts, and logging
/// them as one loses half the record. `nil` means the question does not apply, which is every set
/// logged before this existed and every set of a two-sided exercise.
///
/// Left and right are a pair, not two sets: they are numbered together, counted as one, and rested
/// between rather than after. See `WorkoutExerciseModel.loggedSetCount`.
enum SetSide: String, Codable, CaseIterable, Identifiable, Sendable {

    var id: String { rawValue }

    case left
    case right

    /// Falls back to `nil` rather than throwing on a value written by some future build, matching
    /// how `SetTargetSetType` survives raw values it does not recognise. A set whose side cannot be
    /// read is still a set.
    init?(storedValue: String?) {
        guard let storedValue, let value = SetSide(rawValue: storedValue) else { return nil }
        self = value
    }

    /// The short marker shown beside a set number, as in "2L".
    var initial: String {
        switch self {
        case .left: return "L"
        case .right: return "R"
        }
    }

    var name: String {
        switch self {
        case .left: return String(localized: "Left")
        case .right: return String(localized: "Right")
        }
    }

    /// The side worked first, so a pair reads left then right down the screen.
    static let ordered: [SetSide] = [.left, .right]
}
