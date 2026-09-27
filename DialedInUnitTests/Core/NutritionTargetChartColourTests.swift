//
//  NutritionTargetChartColourTests.swift
//  DialedInUnitTests
//

import Testing
import SwiftUI
@testable import DialedIn

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
