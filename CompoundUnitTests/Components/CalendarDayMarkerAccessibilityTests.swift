//
//  CalendarDayMarkerAccessibilityTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// What VoiceOver says a calendar day holds. The ring and badge are drawn, so this is the only
/// way a marked day sounds different from an empty one.
struct CalendarDayMarkerAccessibilityTests {

    @Test("Test An Empty Day Says Nothing")
    func testAnEmptyDaySaysNothing() {
        #expect(CalendarDayMarker.count(0).accessibilityDescription == nil)
        #expect(CalendarDayMarker.goalProgress(value: 0, goal: 2200, grace: 100).accessibilityDescription == nil)
    }

    @Test("Test Counts Are Spoken")
    func testCountsAreSpoken() {
        #expect(CalendarDayMarker.count(1).accessibilityDescription == "Logged")
        #expect(CalendarDayMarker.count(3).accessibilityDescription == "3 logged")
    }

    @Test("Test Progress Says How Far Toward The Goal")
    func testProgressSaysHowFarTowardTheGoal() {
        let description = CalendarDayMarker.goalProgress(value: 1100, goal: 2200, grace: 100).accessibilityDescription
        #expect(description?.contains(Format.percent(0.5)) == true)
        #expect(description?.contains("Goal met") == false)
        #expect(description?.contains("Over goal") == false)
    }

    /// Met and over were told apart only by the ring's hue, so the words must differ.
    @Test("Test Met And Over Goal Are Told Apart")
    func testMetAndOverGoalAreToldApart() {
        let met = CalendarDayMarker.goalProgress(value: 2250, goal: 2200, grace: 100).accessibilityDescription
        let over = CalendarDayMarker.goalProgress(value: 2650, goal: 2200, grace: 100).accessibilityDescription
        #expect(met?.contains("Goal met") == true)
        #expect(over?.contains("Over goal") == true)
        #expect(over?.contains("Goal met") == false)
    }

    @Test("Test A Day Without A Goal Reads As Logged")
    func testADayWithoutAGoalReadsAsLogged() {
        #expect(CalendarDayMarker.goalProgress(value: 900, goal: 0, grace: 100).accessibilityDescription == "Logged")
    }
}
