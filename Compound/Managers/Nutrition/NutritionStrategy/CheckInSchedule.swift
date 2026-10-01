//
//  CheckInSchedule.swift
//  Compound
//

import Foundation

/// Whether the weekly check-in is waiting, and for which week.
enum CheckInState: Equatable, Sendable {
    /// Nothing to do: this week has already been completed or skipped, or its day has not come.
    case notDue
    /// The check-in for the ISO week beginning `weekStart` has not been dealt with.
    case due(weekStart: Date)
    /// Logging is paused, so the check-in stays out of the way until the break ends.
    case inBreak
}

/// When the weekly check-in is due — the whole rule, as a function of what it reads.
///
/// Pure on purpose, the same way `ExpenditureEngine` is: no `Date()`, no managers, the calendar
/// handed in. A cadence that only reveals itself by waiting until Thursday is not a cadence
/// anyone can maintain.
enum CheckInSchedule {

    /// The check-in week always begins on Monday, whatever the device's calendar says its week
    /// starts on.
    ///
    /// `checkInWeekday` is a `Calendar` weekday (1 = Sunday), and the settings screen offers all
    /// seven. Reading the week through the device's `firstWeekday` would mean a US user's Sunday
    /// check-in opened the *next* week's review, so the week boundary is pinned here instead.
    static func weekStart(for date: Date, calendar: Calendar) -> Date {
        var isoCalendar = calendar
        isoCalendar.firstWeekday = 2
        isoCalendar.minimumDaysInFirstWeek = 4
        let startOfDay = isoCalendar.startOfDay(for: date)
        let offset = dayOffsetInWeek(weekday: isoCalendar.component(.weekday, from: startOfDay))
        return isoCalendar.date(byAdding: .day, value: -offset, to: startOfDay) ?? startOfDay
    }

    /// Days from Monday, so Monday is 0 and Sunday is 6.
    static func dayOffsetInWeek(weekday: Int) -> Int {
        ((weekday - 2) % 7 + 7) % 7
    }

    /// The state of this week's check-in.
    ///
    /// Due from the chosen weekday onwards rather than only on it: a Monday check-in that the user
    /// was too busy for stays on the card through Sunday, because the week's data is just as
    /// reviewable on Thursday and a prompt that vanishes at midnight teaches people to ignore it.
    static func state(
        today: Date,
        settings: NutritionStrategySettings,
        record: CheckInRecord?,
        break loggingBreak: LoggingBreak?,
        calendar: Calendar
    ) -> CheckInState {
        if let loggingBreak, loggingBreak.isOpen(on: today) { return .inBreak }

        let weekStart = weekStart(for: today, calendar: calendar)
        let todayOffset = dayOffsetInWeek(weekday: isoWeekday(for: today, calendar: calendar))
        let checkInOffset = dayOffsetInWeek(weekday: settings.checkInWeekday)
        guard todayOffset >= checkInOffset else { return .notDue }

        if let completed = record?.lastCompletedWeekStart, completed >= weekStart { return .notDue }
        if let skipped = record?.lastSkippedWeekStart, skipped >= weekStart { return .notDue }

        return .due(weekStart: weekStart)
    }

    private static func isoWeekday(for date: Date, calendar: Calendar) -> Int {
        var isoCalendar = calendar
        isoCalendar.firstWeekday = 2
        isoCalendar.minimumDaysInFirstWeek = 4
        return isoCalendar.component(.weekday, from: isoCalendar.startOfDay(for: date))
    }
}
