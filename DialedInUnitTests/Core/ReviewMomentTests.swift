//
//  ReviewMomentTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

/// When the app asks for a rating: after the workout that completes the week's goal, or the
/// seventh day of food logging in a row, and never inside the cooldown or under UI tests.
struct ReviewMomentTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private func asks(_ moment: ReviewMoment, lastRequestedAt: Date = .distantPast, isUITesting: Bool = false) -> Bool {
        ReviewMoment.shouldAsk(at: moment, lastRequestedAt: lastRequestedAt, now: now, isUITesting: isUITesting)
    }

    @Test("Test Only The Workout That Completes The Week Asks")
    func testOnlyTheWorkoutThatCompletesTheWeekAsks() {
        #expect(!asks(.workoutFinished(sessionsThisWeek: 2, weeklyGoal: 3)))
        #expect(asks(.workoutFinished(sessionsThisWeek: 3, weeklyGoal: 3)))
        #expect(!asks(.workoutFinished(sessionsThisWeek: 4, weeklyGoal: 3)))
        #expect(!asks(.workoutFinished(sessionsThisWeek: 0, weeklyGoal: 0)))
    }

    @Test("Test Only The Seventh Day Of Food Logging Asks")
    func testOnlyTheSeventhDayOfFoodLoggingAsks() {
        let asked = (1...10).filter { asks(.foodLogged(daysInARow: $0)) }
        #expect(asked == [7])
    }

    @Test("Test Nothing Asks Inside The Cooldown Or Under UI Tests")
    func testNothingAsksInsideTheCooldownOrUnderUITests() {
        let goalMet = ReviewMoment.workoutFinished(sessionsThisWeek: 3, weeklyGoal: 3)
        #expect(!asks(goalMet, lastRequestedAt: now - 119 * day))
        #expect(asks(goalMet, lastRequestedAt: now - 120 * day))
        #expect(!asks(goalMet, isUITesting: true))
    }

    @Test("Test Days In A Row Stops At The First Gap")
    func testDaysInARowStopsAtTheFirstGap() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let logged = [0, 1, 2, 4, 5].map { now - Double($0) * day }
        // Two entries on the same day count once.
        let withDuplicate = logged + [now - 3600]

        #expect(ReviewMoment.daysInARow(endingOn: now, loggedDays: withDuplicate, calendar: calendar) == 3)
        #expect(ReviewMoment.daysInARow(endingOn: now + day, loggedDays: logged, calendar: calendar) == 0)
    }
}
