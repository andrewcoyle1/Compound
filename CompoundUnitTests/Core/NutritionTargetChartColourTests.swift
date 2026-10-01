//
//  NutritionTargetChartColourTests.swift
//  CompoundUnitTests
//

import Testing
import SwiftUI
@testable import Compound

/// The weekly target chart drew carbs yellow and fat green, the reverse of every other macro
/// display, and protein in the calories blue.
@MainActor
struct NutritionTargetChartColourTests {

    @Test("Test The Target Chart Uses The App's Macro Colours")
    func testTheTargetChartUsesTheAppsMacroColours() {
        typealias Metric = NutritionTargetChartPresenter.Metric
        #expect(Metric.calories.colour == Macro.cals.colour)
        #expect(Metric.protein.colour == Macro.protein.colour)
        #expect(Metric.carbs.colour == Macro.carbs.colour)
        #expect(Metric.fats.colour == Macro.fat.colour)
    }
}

/// The over-target caret marks only cells well over target (above 110%), so a day a few grams
/// over is not flagged. VoiceOver still says "over target" for anything over 100%.
@MainActor
struct TargetCellCaretTests {

    @Test("Test The Caret Shows Only Above The Threshold")
    func testTheCaretShowsOnlyAboveTheThreshold() {
        #expect(TargetCellView.caretThreshold == 1.1)
        #expect(!TargetCellView.showsCaret(value: 100, target: 100))
        #expect(!TargetCellView.showsCaret(value: 105, target: 100))
        #expect(!TargetCellView.showsCaret(value: 110, target: 100))
        #expect(TargetCellView.showsCaret(value: 111, target: 100))
    }

    @Test("Test No Target Never Shows The Caret")
    func testNoTargetNeverShowsTheCaret() {
        #expect(!TargetCellView.showsCaret(value: 500, target: 0))
    }
}
