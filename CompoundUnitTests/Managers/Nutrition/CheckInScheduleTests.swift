//
//  CheckInScheduleTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// When the weekly check-in is due, on a fixed calendar and a fixed set of days.
///
/// Every case is one of the seven in `docs/specs/weekly-check-in.md` §6.
struct CheckInScheduleTests {

    // MARK: - Fixtures

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private let calendar = CheckInScheduleTests.calendar

    /// Monday 21 September 2026, 00:00 UTC — the start of an ISO week.
    private let monday = Date(timeIntervalSince1970: 1_789_948_800)

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: monday) ?? monday
    }

    private func settings(weekday: Int) -> NutritionStrategySettings {
        var settings = NutritionStrategySettings(authorId: "user-1")
        settings.checkInWeekday = weekday
        return settings
    }

    private func state(
        today: Date,
        weekday: Int = 2,
        record: CheckInRecord? = nil,
        loggingBreak: LoggingBreak? = nil
    ) -> CheckInState {
        CheckInSchedule.state(
            today: today,
            settings: settings(weekday: weekday),
            record: record,
            break: loggingBreak,
            calendar: calendar
        )
    }

    /// The fixture really is a Monday, so every offset below means what it says.
    @Test("Test The Fixture Monday Is A Monday")
    func testTheFixtureMondayIsAMonday() {
        #expect(calendar.component(.weekday, from: monday) == 2)
        #expect(CheckInSchedule.weekStart(for: monday, calendar: calendar) == monday)
        #expect(CheckInSchedule.weekStart(for: day(6), calendar: calendar) == monday)
    }

    // MARK: - Due

    /// Due on the chosen weekday.
    @Test("Test Due On The Check In Weekday")
    func testDueOnTheCheckInWeekday() {
        #expect(state(today: monday) == .due(weekStart: monday))
    }

    /// Still due later in the week when it was not done: the week's data is just as reviewable on
    /// Thursday, and a prompt that vanishes at midnight teaches people to ignore it.
    @Test("Test Still Due Later In The Week")
    func testStillDueLaterInTheWeek() {
        #expect(state(today: day(3)) == .due(weekStart: monday))
        #expect(state(today: day(6)) == .due(weekStart: monday))
    }

    /// Not due before the chosen weekday.
    @Test("Test Not Due Before The Check In Weekday")
    func testNotDueBeforeTheCheckInWeekday() {
        // Friday's check-in, asked about on Wednesday.
        #expect(state(today: day(2), weekday: 6) == .notDue)
    }

    // MARK: - Completion and skipping

    @Test("Test Not Due After Completing This Week")
    func testNotDueAfterCompletingThisWeek() {
        let record = CheckInRecord(authorId: "user-1", lastCompletedWeekStart: monday)
        #expect(state(today: day(2), record: record) == .notDue)
    }

    @Test("Test Not Due After Skipping This Week")
    func testNotDueAfterSkippingThisWeek() {
        let record = CheckInRecord(authorId: "user-1", lastSkippedWeekStart: monday)
        #expect(state(today: day(4), record: record) == .notDue)
    }

    /// Last week's completion says nothing about this one.
    @Test("Test Last Week's Completion Does Not Cover This Week")
    func testLastWeeksCompletionDoesNotCoverThisWeek() {
        let record = CheckInRecord(authorId: "user-1", lastCompletedWeekStart: day(-7))
        #expect(state(today: monday, record: record) == .due(weekStart: monday))
    }

    /// Completing this week does not make next week's earlier days due either — they are before
    /// the check-in weekday.
    @Test("Test Not Due On Next Week's Earlier Days")
    func testNotDueOnNextWeeksEarlierDays() {
        let record = CheckInRecord(authorId: "user-1", lastCompletedWeekStart: monday)
        // Friday check-in: the next Wednesday is a new week but not yet its day.
        #expect(state(today: day(9), weekday: 6, record: record) == .notDue)
    }

    /// And due again when the following check-in day arrives.
    @Test("Test Due Again On The Next Check In Day")
    func testDueAgainOnTheNextCheckInDay() {
        let record = CheckInRecord(authorId: "user-1", lastCompletedWeekStart: monday)
        #expect(state(today: day(7), record: record) == .due(weekStart: day(7)))
    }

    // MARK: - Logging break

    /// An open break outranks everything: a break from logging that still nagged weekly would
    /// not be a break.
    @Test("Test In Break During An Open Break")
    func testInBreakDuringAnOpenBreak() {
        let openBreak = LoggingBreak(authorId: "user-1", startDate: day(-2), endDate: nil)
        #expect(state(today: monday, loggingBreak: openBreak) == .inBreak)
    }

    /// A break that has ended is history, and the check-in comes back.
    @Test("Test A Closed Break Does Not Hold The Check In")
    func testAClosedBreakDoesNotHoldTheCheckIn() {
        let closed = LoggingBreak(authorId: "user-1", startDate: day(-5), endDate: day(-1))
        #expect(state(today: monday, loggingBreak: closed) == .due(weekStart: monday))
    }

    // MARK: - Week boundary

    /// Saturday is weekday 7 and sits inside the ISO week, not at its start.
    @Test("Test A Saturday Check In Falls Inside The Same Week")
    func testASaturdayCheckInFallsInsideTheSameWeek() {
        #expect(state(today: day(4), weekday: 7) == .notDue)
        #expect(state(today: day(5), weekday: 7) == .due(weekStart: monday))
        #expect(state(today: day(6), weekday: 7) == .due(weekStart: monday))
    }

    /// Sunday is weekday 1 — the lowest number, but the last day of the ISO week. Read through
    /// the device's `firstWeekday` it would open the next week's review a day early.
    @Test("Test A Sunday Check In Is The Week's Last Day")
    func testASundayCheckInIsTheWeeksLastDay() {
        #expect(CheckInSchedule.dayOffsetInWeek(weekday: 1) == 6)
        #expect(state(today: day(5), weekday: 1) == .notDue)
        #expect(state(today: day(6), weekday: 1) == .due(weekStart: monday))
        // The following Sunday is a new week, and due again.
        #expect(
            state(
                today: day(13),
                weekday: 1,
                record: CheckInRecord(authorId: "user-1", lastCompletedWeekStart: monday)
            ) == .due(weekStart: day(7))
        )
    }
}
