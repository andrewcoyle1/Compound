//
//  CalendarPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 26/01/2026.
//

import SwiftUI

@Observable
@MainActor
class CalendarPresenter {

    private let interactor: CalendarInteractor
    private let router: CalendarRouter
    private let delegate: CalendarDelegate

    /// One month of the vertical scroll. `days` is padded with `nil` for the weekdays before
    /// the 1st, so the grid lines up without borrowing days from the neighbouring month.
    struct Month: Identifiable, Hashable {
        let id: Date
        let title: String
        let days: [Date?]
    }

    private static let monthsBack = 18
    private static let monthsForward = 6

    let calendar = Calendar.current
    let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private(set) var months: [Month] = []
    private(set) var selectedDate: Date
    private let showsSelection: Bool
    private(set) var today: Date = Calendar.current.startOfDay(for: .now)
    private let selectedHour: Date

    /// The same markers the week strip shows, so a day flagged there is flagged here too.
    private(set) var markers: [Date: CalendarDayMarker] = [:]

    init(
        interactor: CalendarInteractor,
        router: CalendarRouter,
        delegate: CalendarDelegate
    ) {
        self.interactor = interactor
        self.router = router
        self.delegate = delegate
        self.selectedDate = Calendar.current.startOfDay(for: delegate.selectedDate)
        self.showsSelection = delegate.showsSelection
        self.selectedHour = delegate.selectedDate
        self.markers = delegate.markersByDay()

        self.months = buildMonths()
    }

    /// The month the sheet opens on.
    var initialMonth: Date {
        monthStart(for: selectedDate)
    }

    var currentMonth: Date {
        monthStart(for: today)
    }

    func onDateSelected(day: Date) {
        selectedDate = day
        router.dismissScreen()
        delegate.onDateSelected(day, selectedHour)
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    func isSelected(_ day: Date) -> Bool {
        showsSelection && calendar.isDate(day, inSameDayAs: selectedDate)
    }

    func isToday(_ day: Date) -> Bool {
        calendar.isDate(day, inSameDayAs: today)
    }

    func marker(for day: Date) -> CalendarDayMarker? {
        markers[calendar.startOfDay(for: day)]
    }

    private func monthStart(for date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private func buildMonths() -> [Month] {
        let anchor = monthStart(for: today)
        return (-Self.monthsBack...Self.monthsForward).compactMap { offset in
            guard let start = calendar.date(byAdding: .month, value: offset, to: anchor) else { return nil }
            return month(startingAt: start)
        }
    }

    private func month(startingAt start: Date) -> Month? {
        guard let range = calendar.range(of: .day, in: .month, for: start) else { return nil }

        // Weekdays are 1-based from the calendar's own first day, so the offset is how many
        // blank cells sit before the 1st.
        let weekday = calendar.component(.weekday, from: start)
        let leadingBlanks = (weekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for dayOffset in 0..<range.count {
            days.append(calendar.date(byAdding: .day, value: dayOffset, to: start))
        }

        return Month(
            id: start,
            title: start.formatted(.dateTime.year().month(.wide)),
            days: days
        )
    }
}
