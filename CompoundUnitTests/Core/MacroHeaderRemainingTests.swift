//
//  MacroHeaderRemainingTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The "left" figure on the macro header's remaining page, and the one setting that decides
/// whether it may go below zero: `FoodLogSettings.showOverages`.
@MainActor
struct MacroHeaderRemainingTests {

    // MARK: - Off (the default)

    /// What every existing user sees: the figure stops at zero, however far past the target they
    /// have eaten.
    @Test("Test Without Overages A Passed Target Reads Zero")
    func testWithoutOveragesAPassedTargetReadsZero() {
        #expect(MacroHeader.remaining(total: 175, target: 150, showOverages: false) == 0)
        #expect(MacroHeader.remaining(total: 2400, target: 2145, showOverages: false) == 0)
    }

    /// Below target the setting changes nothing, which is where most of a day is spent.
    @Test("Test Below Target Both Settings Agree")
    func testBelowTargetBothSettingsAgree() {
        #expect(MacroHeader.remaining(total: 100, target: 150, showOverages: false) == 50)
        #expect(MacroHeader.remaining(total: 100, target: 150, showOverages: true) == 50)
    }

    // MARK: - On

    /// The point of the setting: how far past the target, not merely that it was passed.
    @Test("Test With Overages A Passed Target Counts Past Zero")
    func testWithOveragesAPassedTargetCountsPastZero() {
        #expect(MacroHeader.remaining(total: 175, target: 150, showOverages: true) == -25)
        #expect(MacroHeader.remaining(total: 2400, target: 2145, showOverages: true) == -255)
    }

    /// Exactly on target is zero either way — there is no overage to show.
    @Test("Test Hitting The Target Exactly Is Zero Either Way")
    func testHittingTheTargetExactlyIsZeroEitherWay() {
        #expect(MacroHeader.remaining(total: 150, target: 150, showOverages: false) == 0)
        #expect(MacroHeader.remaining(total: 150, target: 150, showOverages: true) == 0)
    }

    /// A macro the diet plan does not set has a target of zero. With overages on, anything eaten
    /// of it is an overage, which is true and is what the user asked to see.
    @Test("Test An Unset Target Reads As An Overage When Asked")
    func testAnUnsetTargetReadsAsAnOverageWhenAsked() {
        #expect(MacroHeader.remaining(total: 30, target: 0, showOverages: false) == 0)
        #expect(MacroHeader.remaining(total: 30, target: 0, showOverages: true) == -30)
    }
}
