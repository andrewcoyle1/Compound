//
//  ActiveWorkoutScreenStateTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The tracker's own state, kept beside the session so a rebuilt tracker carries on: stored and
/// read back whole, and never handed to a different session.
struct ActiveWorkoutScreenStateTests {

    private func makeDefaults() throws -> UserDefaults {
        let name = "ActiveWorkoutScreenStateTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private var sample: ActiveWorkoutScreenState {
        ActiveWorkoutScreenState(
            sessionId: "session-1",
            acknowledgedNoteTemplateIds: ["bench", "squat"],
            progressionBaseline: [
                "set-1": SuggestedSet(weightKg: 100, reps: 5),
                "set-2": SuggestedSet(reps: 8, durationSec: 30, distanceMeters: 400)
            ],
            customRestSeconds: ["set-1": 200]
        )
    }

    @Test("Test A Saved State Is Read Back Whole")
    func testRoundTrip() throws {
        let defaults = try makeDefaults()
        sample.save(to: defaults)

        #expect(ActiveWorkoutScreenState.load(sessionId: "session-1", from: defaults) == sample)
    }

    @Test("Test Nothing Stored Reads As An Empty State For The Session")
    func testNothingStored() throws {
        let state = ActiveWorkoutScreenState.load(sessionId: "session-1", from: try makeDefaults())

        #expect(state == ActiveWorkoutScreenState(sessionId: "session-1"))
    }

    /// Left over from a workout already finished or discarded: none of it applies to this one.
    @Test("Test Another Session's State Is Discarded")
    func testAnotherSession() throws {
        let defaults = try makeDefaults()
        sample.save(to: defaults)

        let state = ActiveWorkoutScreenState.load(sessionId: "session-2", from: defaults)

        #expect(state == ActiveWorkoutScreenState(sessionId: "session-2"))
    }

    @Test("Test A Save Replaces The Last One")
    func testSaveReplaces() throws {
        let defaults = try makeDefaults()
        sample.save(to: defaults)
        var next = ActiveWorkoutScreenState(sessionId: "session-2")
        next.customRestSeconds["set-9"] = 45
        next.save(to: defaults)

        #expect(ActiveWorkoutScreenState.load(sessionId: "session-2", from: defaults) == next)
        #expect(ActiveWorkoutScreenState.load(sessionId: "session-1", from: defaults) == ActiveWorkoutScreenState(sessionId: "session-1"))
    }

    @Test("Test An Unreadable Value Reads As An Empty State")
    func testUnreadable() throws {
        let defaults = try makeDefaults()
        defaults.set(Data("not a plist".utf8), forKey: ActiveWorkoutScreenState.storageKey)

        #expect(ActiveWorkoutScreenState.load(sessionId: "session-1", from: defaults) == ActiveWorkoutScreenState(sessionId: "session-1"))
    }
}
