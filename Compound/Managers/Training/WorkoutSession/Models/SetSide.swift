//
//  SetSide.swift
//  Compound
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Foundation

/// Which side of the body a set was performed on.
///
/// Only set for exercises worked one limb at a time. `nil` means the question does not apply, which
/// is every set logged before this existed and every set of a two-sided exercise.
///
/// Such an exercise starts with one `both` row per set: the user nearly always matches the sides
/// and does not reach for their phone between them, so a row per limb was a second tick for
/// nothing. The tracker's Split chip turns each row into a `left`/`right` pair when the sides
/// differ.
///
/// Left and right are a pair, not two sets: they are numbered together, counted as one, and rested
/// between rather than after. See `WorkoutExerciseModel.loggedSetCount`.
enum SetSide: String, Codable, CaseIterable, Identifiable, Sendable {

    var id: String { rawValue }

    case left
    case right
    /// Both sides, logged once with the figures of one. It is still two limbs' work, so volume
    /// counts it twice (`WorkoutSetModel.volumeKg`). A build that predates it reads it as `nil`.
    case both

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
        case .both: return ""
        }
    }

    var name: String {
        switch self {
        case .left: return String(localized: "Left")
        case .right: return String(localized: "Right")
        case .both: return String(localized: "Both sides")
        }
    }
}
