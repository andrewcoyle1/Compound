//
//  PrimarySlotTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// `ActiveWorkout`'s rules for the button at the foot of the tracker, against an injected clock.
@MainActor
struct PrimarySlotTests {

    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let logSet = ActiveWorkoutAction.logSet(exerciseId: "e1", setId: "s1")

    @Test("Test The Slot Logs The Next Set When Nothing Else Is Going On")
    func testLogs() {
        #expect(ActiveWorkout.slotAction(primary: logSet, restEnd: nil, isPaused: false, now: now) == .log(exerciseId: "e1", setId: "s1"))
        #expect(ActiveWorkout.slotAction(primary: .next(exerciseId: "e2"), restEnd: nil, isPaused: false, now: now) == .next(exerciseId: "e2"))
        #expect(ActiveWorkout.slotAction(primary: .finish, restEnd: nil, isPaused: false, now: now) == .finish)
        #expect(ActiveWorkout.slotAction(primary: nil, restEnd: nil, isPaused: false, now: now) == nil)
    }

    @Test("Test The Slot Skips A Rest Still Running")
    func testSkipsRunningRest() {
        let end = now.addingTimeInterval(30)
        #expect(ActiveWorkout.slotAction(primary: logSet, restEnd: end, isPaused: false, now: now) == .skipRest)
        // Even with nothing left to log: the last set's rest still ends before Finish.
        #expect(ActiveWorkout.slotAction(primary: .finish, restEnd: end, isPaused: false, now: now) == .skipRest)
    }

    @Test("Test A Rest That Has Run Out Hands The Slot Back")
    func testExpiredRest() {
        #expect(ActiveWorkout.slotAction(primary: logSet, restEnd: now, isPaused: false, now: now) == .log(exerciseId: "e1", setId: "s1"))
        #expect(ActiveWorkout.slotAction(primary: logSet, restEnd: now.addingTimeInterval(-5), isPaused: false, now: now) == .log(exerciseId: "e1", setId: "s1"))
    }

    @Test("Test Paused, The Slot Resumes Whatever Else Is Going On")
    func testPausedResumes() {
        #expect(ActiveWorkout.slotAction(primary: logSet, restEnd: nil, isPaused: true, now: now) == .resume)
        #expect(ActiveWorkout.slotAction(primary: logSet, restEnd: now.addingTimeInterval(30), isPaused: true, now: now) == .resume)
        #expect(ActiveWorkout.slotAction(primary: nil, restEnd: nil, isPaused: true, now: now) == .resume)
    }

    @Test("Test The Grace Lasts One Second From The Rest's End")
    func testGrace() {
        let end = now
        #expect(!ActiveWorkout.isInGrace(restEnd: end, now: end.addingTimeInterval(-0.1)))
        #expect(ActiveWorkout.isInGrace(restEnd: end, now: end))
        #expect(ActiveWorkout.isInGrace(restEnd: end, now: end.addingTimeInterval(0.99)))
        #expect(!ActiveWorkout.isInGrace(restEnd: end, now: end.addingTimeInterval(1)))
        #expect(!ActiveWorkout.isInGrace(restEnd: end, now: end.addingTimeInterval(60)))
    }

    @Test("Test A Tap Counts Only From 0.4 Seconds After The Action Changed")
    func testTapLockout() {
        #expect(ActiveWorkout.acceptsTap(lastActionChangeAt: nil, now: now))
        #expect(!ActiveWorkout.acceptsTap(lastActionChangeAt: now, now: now))
        #expect(!ActiveWorkout.acceptsTap(lastActionChangeAt: now, now: now.addingTimeInterval(0.39)))
        #expect(ActiveWorkout.acceptsTap(lastActionChangeAt: now, now: now.addingTimeInterval(0.41)))
        #expect(ActiveWorkout.acceptsTap(lastActionChangeAt: now, now: now.addingTimeInterval(5)))
    }
}
