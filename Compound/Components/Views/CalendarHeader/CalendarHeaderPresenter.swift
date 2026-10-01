import SwiftUI

@Observable
@MainActor
class CalendarHeaderPresenter {
    
    private let interactor: CalendarHeaderInteractor
    private let router: CalendarHeaderRouter
    private let delegate: CalendarHeaderDelegate

    let calendar = Calendar.current

    /// The day the strip is centred on, and the month the expanded calendar opens at. Whether
    /// it is *shown* as selected is the host's call — see `CalendarHeaderDelegate.showsSelection`.
    var focusedDate: Date = Date()

    /// Refreshed on `NSCalendarDayChanged`; as a value captured at init, a session left open
    /// past midnight kept highlighting yesterday.
    private(set) var today: Date = Calendar.current.startOfDay(for: .now)

    /// Held between the day being picked in the expanded calendar and that sheet finishing its
    /// dismissal, when the host screen's action can safely run.
    private var dateAwaitingHostAction: Date?

    /// How far the strip reaches either side of the day it is built around. Fixed rather than
    /// loaded as the user scrolls: inserting days ahead of the visible ones shifts every cell
    /// mid-fling. A date picked beyond it in the expanded calendar rebuilds the range instead.
    private static let daysBack = 365
    private static let daysAhead = 100

    /// How many cells are on screen at once. The strip pages one day at a time, so the leading
    /// cell and the visible window are no longer the same thing.
    static let visibleDayCount: Int = 7

    /// Every day the strip can reach, flat rather than grouped into weeks: the scroll view pages
    /// by day, so a day is both the `ForEach` identity and the `scrollPosition(id:)` target.
    ///
    /// Cached because the view reads this while scrolling. As a computed property it rebuilt the
    /// whole range on every body pass, which showed up as stutter in the header.
    private(set) var days: [Date] = []

    init(interactor: CalendarHeaderInteractor, router: CalendarHeaderRouter, delegate: CalendarHeaderDelegate) {
        self.interactor = interactor
        self.router = router
        self.delegate = delegate

        let today = calendar.startOfDay(for: Date())
        self.days = Self.days(around: today, today: today, calendar: calendar)
    }

    /// The week containing today, for the view's initial scroll position.
    var currentWeekStart: Date {
        weekStart(for: .now)
    }

    /// The page the strip has to scroll to in order to show `date`.
    func weekStart(for date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    func refreshToday() {
        today = calendar.startOfDay(for: .now)
    }

    /// A year back from `anchor` to `daysAhead` past whichever is later of it and today, so the
    /// "today" button always has today to scroll to, however far back the anchor is.
    static func days(around anchor: Date, today: Date, calendar: Calendar) -> [Date] {
        let anchor = calendar.startOfDay(for: anchor)
        let startDate = calendar.date(byAdding: .day, value: -daysBack, to: anchor) ?? anchor
        let endDate = calendar.date(byAdding: .day, value: daysAhead, to: max(anchor, today)) ?? anchor

        // Starts on a week boundary so that scrolling to a week start always has that week's
        // seven days ahead of it, which is what the "today" button relies on.
        guard let firstDay = calendar.dateInterval(of: .weekOfYear, for: startDate)?.start else {
            return []
        }

        var result: [Date] = []
        var day = calendar.startOfDay(for: firstDay)
        let finalDay = calendar.startOfDay(for: endDate)

        while day <= finalDay {
            result.append(day)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = calendar.startOfDay(for: nextDay)
        }

        return result
    }

    /// Whether `day` is one of the cells on screen, given the leading cell the view reports.
    /// A nil leading day means the strip has not settled yet, so nothing is treated as off-screen.
    func isVisible(_ day: Date, fromLeadingDay leadingDay: Date?) -> Bool {
        guard
            let leadingDay,
            let lastVisibleDay = calendar.date(
                byAdding: .day,
                value: Self.visibleDayCount - 1,
                to: calendar.startOfDay(for: leadingDay)
            )
        else {
            return true
        }

        let target = calendar.startOfDay(for: day)
        return target >= calendar.startOfDay(for: leadingDay) && target <= calendar.startOfDay(for: lastVisibleDay)
    }

    func isTodayVisible(fromLeadingDay leadingDay: Date?) -> Bool {
        isVisible(today, fromLeadingDay: leadingDay)
    }

    /// Which way today lies from the visible window, so the button can point at it rather than
    /// guessing a direction.
    func isTodayAhead(ofLeadingDay leadingDay: Date?) -> Bool {
        guard let leadingDay else { return false }
        return today > calendar.startOfDay(for: leadingDay)
    }

    func onReturnToTodayPressed() {
        interactor.trackEvent(event: Event.returnedToToday)
    }

    func isSelected(_ day: Date) -> Bool {
        delegate.showsSelection && calendar.isDate(day, inSameDayAs: focusedDate)
    }

    func onDatePressed(_ date: Date) {
        interactor.trackEvent(event: Event.dateSelectionFunctionTriggered)
        focusedDate = date
        delegate.onDatePressed(date)
    }

    /// `onDismiss` lets the view clear the binding the parent's toolbar button set, so the
    /// button works again on the next press.
    func showLargeCalendar(
        _ transitionId: String,
        in namespace: Namespace.ID,
        onDismiss: @escaping () -> Void = { }
    ) {
        interactor.trackEvent(event: Event.openLargeCalendar)
        router.showCalendarViewZoom(
            delegate: CalendarDelegate(
                selectedDate: focusedDate,
                showsSelection: delegate.showsSelection,
                // The strip follows the selection right away, behind the dismissing sheet. The
                // host action waits for `onDidDismiss` below: Training's opens a session detail
                // screen through its own router, and the router sweeps away anything presented
                // before its dismissal clean-up has run.
                onDateSelected: { [weak self] date, _ in
                    guard let self else { return }
                    self.interactor.trackEvent(event: Event.datePickedFromCalendar)
                    self.rebuildDaysIfOutside(date)
                    self.focusedDate = date
                    self.dateAwaitingHostAction = date
                },
                markersByDay: delegate.markersByDay
            ),
            onDismiss: onDismiss,
            onDidDismiss: { [weak self] in
                guard let self, let date = self.dateAwaitingHostAction else { return }
                self.dateAwaitingHostAction = nil
                self.delegate.onDatePressed(date)
            },
            transitionId: transitionId,
            namespace: namespace
        )
    }

    /// Rebuilds the strip around `date` when it is beyond either end, before `focusedDate`
    /// moves, so the day the view scrolls to exists. This runs behind the dismissing sheet, so
    /// swapping the data out does not show.
    func rebuildDaysIfOutside(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        guard let first = days.first, let last = days.last, day < first || day > last else { return }
        days = Self.days(around: day, today: today, calendar: calendar)
    }

    /// One map for the whole header rather than a lookup per cell. Each `getForDate` call used
    /// to filter every session or meal, so a single body pass ran seven full scans.
    func markersByDay() -> [Date: CalendarDayMarker] {
        delegate.markersByDay()
    }

    enum Event: LoggableEvent {
        case openLargeCalendar
        case datePickedFromCalendar
        case dateSelectionFunctionTriggered
        case returnedToToday

        var eventName: String {
            switch self {
            case .openLargeCalendar:                return "CalendarHeader_OpenLargeCalendar"
            case .datePickedFromCalendar:           return "CalendarHeader_DatePickedFromLargeCalendar"
            case .dateSelectionFunctionTriggered:   return "CalendarHeader_DateSelectionFunction_Triggered"
            case .returnedToToday:                  return "CalendarHeader_ReturnedToToday"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            default:
                return .info
            }
        }
    }

}
