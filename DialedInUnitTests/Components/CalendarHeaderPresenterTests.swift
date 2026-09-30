//
//  CalendarHeaderPresenterTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The calendar strip shared by Training and Nutrition.
///
/// `showCalendarViewZoom` needs a `Namespace.ID`, which cannot be made outside a view, so these
/// tests stay on the side of the presenter that does not present: picking a day in the strip.
@MainActor
struct CalendarHeaderPresenterTests {

    private final class Interactor: CalendarHeaderInteractor {
        private(set) var trackedEventNames: [String] = []

        func trackEvent(event: LoggableEvent) {
            trackedEventNames.append(event.eventName)
        }
    }

    private final class Router: CalendarHeaderRouter {
        func showCalendarViewZoom(
            delegate: CalendarDelegate,
            onDismiss: (() -> Void)?,
            onDidDismiss: (() -> Void)?,
            transitionId: String?,
            namespace: Namespace.ID
        ) { }
    }

    private final class Host {
        private(set) var pressedDates: [Date] = []

        func record(_ date: Date) { pressedDates.append(date) }
    }

    private struct Screen {
        let presenter: CalendarHeaderPresenter
        let interactor: Interactor
        let host: Host
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let host = Host()
        let delegate = CalendarHeaderDelegate(
            onDatePressed: { host.record($0) },
            markersByDay: { [:] }
        )
        return Screen(
            presenter: CalendarHeaderPresenter(interactor: interactor, router: Router(), delegate: delegate),
            interactor: interactor,
            host: host
        )
    }

    private let day = Date(timeIntervalSince1970: 1_772_000_000)

    @Test("Test Pressing A Day Focuses It And Tells The Host")
    func testPressingADayFocusesItAndTellsTheHost() {
        let screen = makeScreen()

        screen.presenter.onDatePressed(day)

        #expect(screen.presenter.focusedDate == day)
        #expect(screen.host.pressedDates == [day])
    }

    /// Picking a day in the expanded calendar was tracked and returning to today was tracked, but
    /// the strip's own taps — by far the commonest way a day is chosen — were not.
    @Test("Test Pressing A Day In The Strip Is Tracked")
    func testPressingADayInTheStripIsTracked() {
        let screen = makeScreen()

        screen.presenter.onDatePressed(day)

        #expect(screen.interactor.trackedEventNames == ["CalendarHeader_DateSelectionFunction_Triggered"])
    }

    @Test("Test Returning To Today Is Tracked")
    func testReturningToTodayIsTracked() {
        let screen = makeScreen()

        screen.presenter.onReturnToTodayPressed()

        #expect(screen.interactor.trackedEventNames == ["CalendarHeader_ReturnedToToday"])
    }

    @Test("Test The Strip Reaches A Year Back And Today")
    func testTheStripReachesAYearBackAndToday() throws {
        let presenter = makeScreen().presenter
        let calendar = presenter.calendar
        let yearAgo = try #require(calendar.date(byAdding: .day, value: -365, to: presenter.today))

        let first = try #require(presenter.days.first)
        let last = try #require(presenter.days.last)
        #expect(first <= yearAgo)
        #expect(last > presenter.today)
    }

    @Test("Test A Day Beyond The Strip Rebuilds It Around That Day, Still Reaching Today")
    func testADayBeyondTheStripRebuildsItAroundThatDay() throws {
        let presenter = makeScreen().presenter
        let calendar = presenter.calendar
        let farBack = try #require(calendar.date(byAdding: .year, value: -3, to: presenter.today))

        presenter.rebuildDaysIfOutside(farBack)

        #expect(presenter.days.contains(farBack))
        #expect(try #require(presenter.days.first) < farBack)
        #expect(presenter.days.contains(presenter.today))
    }

    @Test("Test A Day Already In The Strip Leaves It Alone")
    func testADayAlreadyInTheStripLeavesItAlone() {
        let presenter = makeScreen().presenter
        let before = presenter.days

        presenter.rebuildDaysIfOutside(presenter.today)

        #expect(presenter.days == before)
    }
}
