//
//  WorkoutPausedTimeTests.swift
//  DialedInUnitTests
//
//  A saved workout's duration is active time: the time spent paused is stamped on the session
//  when it is finished and left out of `activeDuration`, which every duration display reads.
//

import Testing
import Foundation
@testable import DialedIn

@MainActor
struct WorkoutPausedTimeTests {

    private let start = Date(timeIntervalSince1970: 1_772_000_000)

    private func session() -> WorkoutSessionModel {
        WorkoutSessionModel(id: "s1", authorId: "a1", name: "Upper", dateCreated: start, exercises: [])
    }

    @Test("Test A Session Never Paused Lasts From Start To End")
    func testASessionNeverPausedLastsFromStartToEnd() {
        var ended = session()
        ended.endSession(at: start.addingTimeInterval(3600))
        #expect(ended.pausedSeconds == nil)
        #expect(ended.activeDuration == 3600)
    }

    @Test("Test Paused Time Is Left Out Of The Duration")
    func testPausedTimeIsLeftOutOfTheDuration() {
        var ended = session()
        ended.endSession(at: start.addingTimeInterval(3600), pausedSeconds: 600)
        #expect(ended.activeDuration == 3000)
    }

    @Test("Test A Running Session Has No Duration")
    func testARunningSessionHasNoDuration() {
        #expect(session().activeDuration == nil)
    }

    /// A session saved before the field existed has no `paused_seconds`, and reads exactly as it
    /// did: end minus start.
    @Test("Test A Session Saved Before Paused Time Existed Reads As Before")
    func testASessionSavedBeforePausedTimeExistedReadsAsBefore() throws {
        var ended = session()
        ended.endSession(at: start.addingTimeInterval(2700))
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(ended)) as? [String: Any])
        #expect(json["paused_seconds"] == nil)
        json.removeValue(forKey: "paused_seconds")
        let decoded = try JSONDecoder().decode(WorkoutSessionModel.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.pausedSeconds == nil)
        #expect(decoded.activeDuration == 2700)
    }

    @Test("Test Paused Time Survives Being Saved And Read Back")
    func testPausedTimeSurvivesBeingSavedAndReadBack() throws {
        var ended = session()
        ended.endSession(at: start.addingTimeInterval(3600), pausedSeconds: 300)
        let decoded = try JSONDecoder().decode(WorkoutSessionModel.self, from: JSONEncoder().encode(ended))
        #expect(decoded.pausedSeconds == 300)
        #expect(decoded.activeDuration == 3300)
    }

    /// Editing the duration sets active time, so the paused time stays out of what is shown.
    @Test("Test Editing The Duration Sets Active Time")
    func testEditingTheDurationSetsActiveTime() {
        var ended = session()
        ended.endSession(at: start.addingTimeInterval(3600), pausedSeconds: 600)
        ended.updateDuration(1800)
        #expect(ended.activeDuration == 1800)
        #expect(ended.endedAt == start.addingTimeInterval(2400))
    }

    @Test("Test Paused Time Longer Than The Workout Never Makes It Negative")
    func testPausedTimeLongerThanTheWorkoutNeverMakesItNegative() {
        var ended = session()
        ended.endSession(at: start.addingTimeInterval(60), pausedSeconds: 120)
        #expect(ended.activeDuration == 0)
    }
}

#if canImport(HealthKit) && !targetEnvironment(macCatalyst)

/// The paused total the finish stamps comes from `HKWorkoutManager`, which keeps the pause whether
/// or not a HealthKit session is running.
@MainActor
struct WorkoutPauseTotalTests {

    private func manager() -> HKWorkoutManager {
        HKWorkoutManager(logger: LogManager(), liveActivityUpdater: nil, restOverNotifier: RestOverNotifierSpy())
    }

    /// Finishing while paused: the pause still running counts up to the moment of finishing.
    @Test("Test A Workout Finished While Paused Counts The Current Pause")
    func testAWorkoutFinishedWhilePausedCountsTheCurrentPause() throws {
        let hkManager = manager()
        hkManager.pause()
        let pausedAt = try #require(hkManager.pausedAt)
        #expect(hkManager.totalPausedDuration(at: pausedAt.addingTimeInterval(90)) == 90)
    }

    /// Pausing twice: the first pause is kept, and the second adds to it.
    @Test("Test Pausing More Than Once Adds Up")
    func testPausingMoreThanOnceAddsUp() throws {
        let hkManager = manager()
        hkManager.pause()
        hkManager.resume()
        let first = hkManager.pausedDuration
        hkManager.pause()
        let secondStart = try #require(hkManager.pausedAt)
        #expect(hkManager.totalPausedDuration(at: secondStart.addingTimeInterval(30)) == first + 30)
        hkManager.resume()
        #expect(hkManager.totalPausedDuration(at: .now.addingTimeInterval(1000)) == hkManager.pausedDuration)
        #expect(hkManager.pausedDuration >= first)
    }

    /// Stamped on the session, a running pause and an earlier one both come out of the duration.
    @Test("Test The Stamped Total Leaves Every Pause Out Of The Duration")
    func testTheStampedTotalLeavesEveryPauseOutOfTheDuration() throws {
        let hkManager = manager()
        hkManager.pause()
        hkManager.resume()
        hkManager.pause()
        let pausedAt = try #require(hkManager.pausedAt)
        let finish = pausedAt.addingTimeInterval(120)
        let paused = hkManager.totalPausedDuration(at: finish)
        let start = finish.addingTimeInterval(-3600)
        var session = WorkoutSessionModel(id: "s1", authorId: "a1", name: "Upper", dateCreated: start, exercises: [])
        session.endSession(at: finish, pausedSeconds: paused)
        let duration = try #require(session.activeDuration)
        #expect(abs(duration - (3600 - paused)) < 0.001)
        #expect(duration <= 3480)
    }
}

#endif
