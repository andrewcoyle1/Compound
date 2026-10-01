//
//  DateExtensionTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The date helpers the rest of the app counts days with.
///
/// `dayKey` is the important one: it is the document id every meal, step count and daily total is
/// stored under, so it has to be the same string for the same calendar day, forever, in every
/// locale. It pins its own calendar and locale for exactly that reason, and these tests check it
/// stayed pinned.
@MainActor
struct DateExtensionTests {

    private let calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: - dayKey

    @Test("Test Day Key Is The Calendar Day")
    func testDayKeyIsTheCalendarDay() {
        #expect(date(2026, 9, 20).dayKey == "2026-09-20")
        #expect(date(2026, 1, 1).dayKey == "2026-01-01")
        #expect(date(2026, 12, 31).dayKey == "2026-12-31")
    }

    /// Any time of day gives the same key, or a meal logged at 11pm would land on its own day.
    @Test("Test Day Key Ignores The Time")
    func testDayKeyIgnoresTheTime() {
        let earliest = date(2026, 9, 20, 0, 0)
        let latest = date(2026, 9, 20, 23, 59)

        #expect(earliest.dayKey == latest.dayKey)
        #expect(earliest.dayKey == "2026-09-20")
    }

    @Test("Test Day Key Pads Single Digits")
    func testDayKeyPadsSingleDigits() {
        // Not "2026-9-5": the keys are compared and sorted as strings.
        #expect(date(2026, 9, 5).dayKey == "2026-09-05")
        #expect(date(2026, 1, 9).dayKey.count == 10)
    }

    @Test("Test Day Keys Sort Chronologically As Strings")
    func testDayKeysSortChronologicallyAsStrings() {
        let keys = [date(2026, 12, 1), date(2026, 2, 3), date(2025, 11, 30), date(2026, 2, 20)].map(\.dayKey)

        #expect(keys.sorted() == ["2025-11-30", "2026-02-03", "2026-02-20", "2026-12-01"])
    }

    // MARK: - Parsing a day key

    @Test("Test A Day Key Round Trips")
    func testADayKeyRoundTrips() throws {
        let original = date(2026, 9, 20)
        let parsed = try #require(Date(dayKey: original.dayKey))

        #expect(parsed.dayKey == original.dayKey)
        #expect(calendar.isDate(parsed, inSameDayAs: original))
    }

    @Test("Test Parsing Gives The Start Of The Day")
    func testParsingGivesTheStartOfTheDay() throws {
        let parsed = try #require(Date(dayKey: "2026-09-20"))

        #expect(calendar.component(.hour, from: parsed) == 0)
        #expect(calendar.component(.minute, from: parsed) == 0)
    }

    @Test("Test An Empty Day Key Parses To Nothing")
    func testAnEmptyDayKeyParsesToNothing() {
        #expect(Date(dayKey: "") == nil)
    }

    @Test("Test Text Parses To Nothing")
    func testTextParsesToNothing() {
        #expect(Date(dayKey: "not a date") == nil)
    }

    @Test("Test A Reversed Day Key Parses To Nothing")
    func testAReversedDayKeyParsesToNothing() {
        #expect(Date(dayKey: "20-09-2026") == nil)
    }

    /// `DateFormatter` is lenient about the separator, so a key written with slashes parses to the
    /// same day as one written with dashes. Pinned as it behaves, not as the format string reads:
    /// nothing in the app writes slashes, and a stored key that somehow had them still resolves to
    /// the right day rather than being dropped.
    @Test("Test Slashes Parse To The Same Day")
    func testSlashesParseToTheSameDay() throws {
        let withSlashes = try #require(Date(dayKey: "2026/09/20"))

        #expect(withSlashes.dayKey == "2026-09-20")
    }

    // MARK: - Ranges of day keys

    @Test("Test A Range Of Day Keys Includes Both Ends")
    func testARangeOfDayKeysIncludesBothEnds() {
        let keys = Date.dayKeys(from: date(2026, 9, 18), to: date(2026, 9, 20))

        #expect(keys == ["2026-09-18", "2026-09-19", "2026-09-20"])
    }

    @Test("Test A One Day Range Is One Key")
    func testAOneDayRangeIsOneKey() {
        #expect(Date.dayKeys(from: date(2026, 9, 20), to: date(2026, 9, 20)) == ["2026-09-20"])
    }

    @Test("Test A Backwards Range Is Empty")
    func testABackwardsRangeIsEmpty() {
        #expect(Date.dayKeys(from: date(2026, 9, 20), to: date(2026, 9, 18)).isEmpty)
    }

    @Test("Test A Range Crosses Month And Year Boundaries")
    func testARangeCrossesMonthAndYearBoundaries() {
        #expect(Date.dayKeys(from: date(2026, 1, 30), to: date(2026, 2, 2))
            == ["2026-01-30", "2026-01-31", "2026-02-01", "2026-02-02"])
        #expect(Date.dayKeys(from: date(2025, 12, 31), to: date(2026, 1, 1))
            == ["2025-12-31", "2026-01-01"])
    }

    /// The nutrition screens ask for ninety days at a time.
    @Test("Test A Ninety Day Range Has Ninety Days")
    func testANinetyDayRangeHasNinetyDays() {
        let end = date(2026, 9, 20)
        let start = calendar.date(byAdding: .day, value: -89, to: end)!

        #expect(Date.dayKeys(from: start, to: end).count == 90)
    }

    // MARK: - Month boundaries

    @Test("Test Start And End Of Month")
    func testStartAndEndOfMonth() {
        let inSeptember = date(2026, 9, 20)

        #expect(calendar.component(.day, from: inSeptember.startOfMonth) == 1)
        #expect(calendar.component(.day, from: inSeptember.endOfMonth) == 30)
        #expect(calendar.component(.month, from: inSeptember.endOfMonth) == 9)
    }

    @Test("Test The Number Of Days In A Month")
    func testTheNumberOfDaysInAMonth() {
        #expect(date(2026, 1, 15).numberOfDaysInMonth == 31)
        #expect(date(2026, 4, 15).numberOfDaysInMonth == 30)
        #expect(date(2026, 2, 15).numberOfDaysInMonth == 28)
        // 2024 is a leap year; 2100 is not, despite dividing by four.
        #expect(date(2024, 2, 15).numberOfDaysInMonth == 29)
        #expect(date(2100, 2, 15).numberOfDaysInMonth == 28)
    }

    @Test("Test A Calendar Month Shows Whole Weeks Plus Its Own Days")
    func testACalendarMonthShowsWholeWeeksPlusItsOwnDays() {
        let days = date(2026, 9, 20).calendarDisplayDays

        // The leading days come from the previous month, then every day of this one.
        #expect(days.count >= 30)
        #expect(days.count <= 30 + 6)
        #expect(days.last.map { calendar.component(.day, from: $0) } == 30)
    }

    // MARK: - Arithmetic

    @Test("Test Adding Days")
    func testAddingDays() {
        let start = date(2026, 9, 20)

        #expect(start.addingDays(1).dayKey == "2026-09-21")
        #expect(start.addingDays(-1).dayKey == "2026-09-19")
        #expect(start.addingDays(0).dayKey == "2026-09-20")
        #expect(start.addingDays(11).dayKey == "2026-10-01")
    }

    @Test("Test Adding Days, Hours And Minutes")
    func testAddingDaysHoursAndMinutes() {
        let start = date(2026, 9, 20, 10, 0)
        let later = start.addingTimeInterval(days: 1, hours: 2, minutes: 30)

        #expect(later.timeIntervalSince(start) == 86400 + 7200 + 1800)
    }

    @Test("Test Start Of Day Clears The Time")
    func testStartOfDayClearsTheTime() {
        let afternoon = date(2026, 9, 20, 15, 45)

        #expect(afternoon.startOfDay.hourInt == 0)
        #expect(afternoon.startOfDay.minuteInt == 0)
        #expect(afternoon.hourInt == 15)
        #expect(afternoon.minuteInt == 45)
        #expect(afternoon.monthInt == 9)
    }

    // MARK: - Durations

    @Test("Test Durations Under An Hour Show Only Minutes")
    func testDurationsUnderAnHourShowOnlyMinutes() {
        #expect(Date.formatDuration(0) == "0m")
        #expect(Date.formatDuration(45 * 60) == "45m")
        #expect(Date.formatDuration(59 * 60 + 59) == "59m")
    }

    @Test("Test Longer Durations Show Hours And Minutes")
    func testLongerDurationsShowHoursAndMinutes() {
        #expect(Date.formatDuration(3600) == "1h 0m")
        #expect(Date.formatDuration(3600 + 23 * 60) == "1h 23m")
        #expect(Date.formatDuration(2 * 3600 + 5 * 60) == "2h 5m")
    }

    // MARK: - Weekday labels

    @Test("Test There Are Seven Weekday Initials")
    func testThereAreSevenWeekdayInitials() {
        let weekdays = Date.capitalizedFirstLettersOfWeekdays

        #expect(weekdays.count == 7)
        #expect(Set(weekdays).count >= 5) // Tue/Thu and Sat/Sun can share an initial
    }
}
