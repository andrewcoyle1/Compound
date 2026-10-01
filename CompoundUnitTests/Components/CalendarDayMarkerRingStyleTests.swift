//
//  CalendarDayMarkerRingStyleTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// Goal-met and over-goal rings used to differ only by hue (green vs. red), which is invisible to
/// colour-blind users. `ringIsDashed` is what `CalendarDayCell` now reads to also change shape.
struct CalendarDayMarkerRingStyleTests {

    @Test("Test A Day That Met Its Goal Is Solid")
    func testADayThatMetItsGoalIsSolid() {
        #expect(CalendarDayMarker.goalProgress(value: 2250, goal: 2200, grace: 100).ringIsDashed == false)
    }

    @Test("Test A Day Over Goal Is Dashed")
    func testADayOverGoalIsDashed() {
        #expect(CalendarDayMarker.goalProgress(value: 2650, goal: 2200, grace: 100).ringIsDashed == true)
    }

    @Test("Test A Count Marker Is Never Dashed")
    func testACountMarkerIsNeverDashed() {
        #expect(CalendarDayMarker.count(3).ringIsDashed == false)
    }

    @Test("Test A Day Within Grace Is Solid")
    func testADayWithinGraceIsSolid() {
        #expect(CalendarDayMarker.goalProgress(value: 2290, goal: 2200, grace: 100).ringIsDashed == false)
    }
}
