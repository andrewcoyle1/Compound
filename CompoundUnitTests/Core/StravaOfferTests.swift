//
//  StravaOfferTests.swift
//  CompoundUnitTests
//
//  Strava is offered once, after the first finished workout has saved, to someone not connected.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct StravaOfferTests {

    private let start = Date(timeIntervalSince1970: 1_772_000_000)

    private func finished(_ id: String, author: String = "a1", restDay: Bool = false, deleted: Bool = false) -> WorkoutSessionModel {
        WorkoutSessionModel(
            id: id, authorId: author, name: "Upper", dateCreated: start, endedAt: start.addingTimeInterval(3600),
            exercises: [], deletedAt: deleted ? start : nil, isRestDay: restDay
        )
    }

    private func offer(_ session: WorkoutSessionModel, saved: [WorkoutSessionModel], connected: Bool = false, answered: Bool = false) -> Bool {
        StravaOffer.shouldOffer(finished: session, savedSessions: saved, isStravaConnected: connected, hasAnswered: answered)
    }

    @Test("Test The First Finished Workout Is The Moment")
    func testTheFirstFinishedWorkoutIsTheMoment() {
        let first = finished("w1")
        #expect(offer(first, saved: [first]))
    }

    @Test("Test Not Before The Workout Has Saved")
    func testNotBeforeTheWorkoutHasSaved() {
        #expect(!offer(finished("w1"), saved: []))
    }

    @Test("Test Not After A Second Workout")
    func testNotAfterASecondWorkout() {
        let second = finished("w2")
        #expect(!offer(second, saved: [finished("w1"), second]))
    }

    @Test("Test Rest Days, Deleted Sessions And Other People's Do Not Count As Earlier Workouts")
    func testRestDaysDeletedAndOtherAuthorsDoNotCount() {
        let first = finished("w1")
        let others = [finished("r1", restDay: true), finished("d1", deleted: true), finished("o1", author: "someone-else")]
        #expect(offer(first, saved: others + [first]))
    }

    @Test("Test Never When Strava Is Connected Or The Offer Was Answered")
    func testNeverWhenConnectedOrAnswered() {
        let first = finished("w1")
        #expect(!offer(first, saved: [first], connected: true))
        #expect(!offer(first, saved: [first], answered: true))
    }

    @Test("Test A Rest Day Is Not A Finished Workout")
    func testARestDayIsNotAFinishedWorkout() {
        let rest = finished("r1", restDay: true)
        #expect(!offer(rest, saved: [rest]))
    }

    @Test("Test The Answer Is Kept Per Person")
    func testTheAnswerIsKeptPerPerson() {
        #expect(StravaOffer.answeredKey(userId: "a") != StravaOffer.answeredKey(userId: "b"))
    }
}
