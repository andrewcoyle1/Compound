//
//  ActiveWorkoutScreenState.swift
//  Compound
//
//  What the tracker knows beyond the session itself, kept so a tracker rebuilt after a minimise
//  or a relaunch carries on where the last one left off.
//

import Foundation

/// The tracker's own state for one session: progression notes already dismissed, the values the
/// screen filled in (so an edited set is still told from a suggested one), rests set by hand on a
/// row, and the exercise the user is on.
///
/// One value under one key in the App Group's defaults. A stored value for any other session is
/// stale and is never handed back.
struct ActiveWorkoutScreenState: Codable, Equatable {
    var sessionId: String
    /// Exercise template ids whose progression note has been dismissed.
    var acknowledgedNoteTemplateIds: Set<String> = []
    /// What the screen filled in, by set id. See `WorkoutTrackerPresenter.progressionBaseline`.
    var progressionBaseline: [String: SuggestedSet] = [:]
    /// Rests set by hand on a row, by set id.
    var customRestSeconds: [String: Int] = [:]
    /// The exercise the user is on, written by the tracker when its card moves and by the Live
    /// Activity's handler when a set is logged there, so both carry on from the same exercise.
    var focusExerciseId: String?

    static let storageKey = "workout.tracker.screenState"

    /// Where the tracker keeps it: the App Group, beside the rest end time.
    static var appGroupStore: UserDefaults {
        UserDefaults(suiteName: Constants.appGroupIdentifier) ?? .standard
    }

    /// The state stored for `sessionId`, or an empty one when none is (or it belongs to another
    /// session, or cannot be read).
    static func load(sessionId: String, from defaults: UserDefaults) -> ActiveWorkoutScreenState {
        guard let data = defaults.data(forKey: storageKey),
              let stored = try? PropertyListDecoder().decode(Self.self, from: data),
              stored.sessionId == sessionId
        else { return ActiveWorkoutScreenState(sessionId: sessionId) }
        return stored
    }

    /// A `nil` focus keeps the one stored: the tracker writes its other fields without it.
    func save(to defaults: UserDefaults) {
        var state = self
        if state.focusExerciseId == nil {
            state.focusExerciseId = Self.load(sessionId: sessionId, from: defaults).focusExerciseId
        }
        do {
            defaults.set(try PropertyListEncoder().encode(state), forKey: Self.storageKey)
        } catch {
            // Strings, integers and optional doubles always encode to a property list.
            assertionFailure("ActiveWorkoutScreenState failed to encode: \(error)")
        }
    }
}

/// Written out by hand because `SuggestedSet` is declared in another file, where the compiler
/// will not synthesise it.
extension SuggestedSet: Codable {
    private enum CodingKeys: String, CodingKey {
        case weightKg, reps, durationSec, distanceMeters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            weightKg: try container.decodeIfPresent(Double.self, forKey: .weightKg),
            reps: try container.decodeIfPresent(Int.self, forKey: .reps),
            durationSec: try container.decodeIfPresent(Int.self, forKey: .durationSec),
            distanceMeters: try container.decodeIfPresent(Double.self, forKey: .distanceMeters)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(weightKg, forKey: .weightKg)
        try container.encodeIfPresent(reps, forKey: .reps)
        try container.encodeIfPresent(durationSec, forKey: .durationSec)
        try container.encodeIfPresent(distanceMeters, forKey: .distanceMeters)
    }
}
