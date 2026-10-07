//
//  MicrocycleVariationsPresenterTests.swift
//  CompoundUnitTests
//
//  How a template exercise's targets vary by week: the summary line, and the screen that adds,
//  moves and deletes the overrides.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct MicrocycleVariationSummaryTests {

    private func sets(_ count: Int) -> [SetTarget] {
        (0..<count).map { SetTarget(setNumber: $0 + 1) }
    }

    @Test("Test Nothing Varies Without Overrides")
    func testNoOverrides() {
        #expect(SetTargetPlan.variationSummary(base: sets(2), overrides: []) == nil)
    }

    @Test("Test Consecutive Overrides Bound Each Other And The Last Runs On")
    func testSummary() {
        let summary = SetTargetPlan.variationSummary(base: sets(2), overrides: [
            MicrocycleSetTargets(fromMicrocycle: 9, setTargets: sets(4)),
            MicrocycleSetTargets(fromMicrocycle: 2, setTargets: sets(3))
        ])

        #expect(summary == "Week 1: 2 sets · Weeks 2–8: 3 sets · From week 9: 4 sets")
    }

    @Test("Test A Base Of Several Weeks And A One-Week Override Read As Ranges")
    func testRanges() {
        let summary = SetTargetPlan.variationSummary(base: sets(3), overrides: [
            MicrocycleSetTargets(fromMicrocycle: 5, setTargets: sets(1)),
            MicrocycleSetTargets(fromMicrocycle: 6, setTargets: sets(3))
        ])

        #expect(summary == "Weeks 1–4: 3 sets · Week 5: 1 set · From week 6: 3 sets")
    }

    @Test("Test An Override From Week 1 Replaces The Base")
    func testOverrideFromWeekOne() {
        let summary = SetTargetPlan.variationSummary(base: sets(3), overrides: [
            MicrocycleSetTargets(fromMicrocycle: 1, setTargets: sets(2))
        ])

        #expect(summary == "From week 1: 2 sets")
    }

    @Test("Test Links Are Saved Only As Web Addresses")
    func testValidatedLink() {
        #expect(SetTargetPlan.validatedLink(" https://youtu.be/abc ") == "https://youtu.be/abc")
        #expect(SetTargetPlan.validatedLink("HTTP://example.com/x?y=1") == "HTTP://example.com/x?y=1")
        #expect(SetTargetPlan.validatedLink("example.com") == nil)
        #expect(SetTargetPlan.validatedLink("ftp://example.com") == nil)
        #expect(SetTargetPlan.validatedLink("https://") == nil)
        #expect(SetTargetPlan.validatedLink("javascript:alert(1)") == nil)
        #expect(SetTargetPlan.validatedLink("") == nil)
    }

    @Test("Test Rest Runs From 15 Seconds To 10 Minutes In 15 Second Steps")
    func testRestChoices() {
        let seconds = SetTargetPlan.restSecondsChoices.compactMap { $0 }

        #expect(SetTargetPlan.restSecondsChoices.first == .some(nil))
        #expect(seconds.first == 15 && seconds.last == 600 && seconds.count == 40)
        #expect(SetTargetPlan.choices(SetTargetPlan.restSecondsChoices, including: 50).compactMap { $0 }.contains(50))
        #expect(SetTargetPlan.choices(SetTargetPlan.warmupSetChoices, including: 5) == [nil, 0, 1, 2, 3, 4, 5])
        #expect(SetTargetPlan.choices(SetTargetPlan.warmupSetChoices, including: 2) == SetTargetPlan.warmupSetChoices)
    }
}
