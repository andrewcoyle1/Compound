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

/// The grid opens on today, and the last column follows the selected day; tapping it again shows
/// the week.
@MainActor
struct NutritionTargetChartSelectionTests {

    private final class Interactor: SpyGlobalInteractor, NutritionTargetChartInteractor {
        var currentDietPlan: DietPlan? { nil }
        func getDailyTotals(dayKey: String) throws -> DailyMacroTarget { DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0) }
    }

    private final class Router: NutritionTargetChartRouter {
        let router: AnyRouter = TestRouting.anyRouter
        func showPreferredDietView(isFromSettings: Bool) { }
    }

    private let logged = [1.0, 2, 3, 4, 5, 6, 7]
    private let targets = [10.0, 20, 30, 40, 50, 60, 70]

    @Test("Test The Grid Opens On Today")
    func testTheGridOpensOnToday() {
        let presenter = NutritionTargetChartPresenter(interactor: Interactor(), router: Router())
        let today = presenter.todayIndexInWeek

        #expect(presenter.selectedDayIndex == today)
        #expect(presenter.summary(logged: logged, targets: targets) == (logged[today], targets[today]))
    }

    @Test("Test Tapping Another Day Shows It And Tapping It Again Shows The Week")
    func testTappingAnotherDayShowsItAndTappingItAgainShowsTheWeek() {
        let interactor = Interactor()
        let presenter = NutritionTargetChartPresenter(interactor: interactor, router: Router())
        let other = (presenter.todayIndexInWeek + 3) % 7

        presenter.onDayPressed(other)
        #expect(presenter.summary(logged: logged, targets: targets) == (logged[other], targets[other]))

        presenter.onDayPressed(other)
        #expect(presenter.selectedDayIndex == nil)
        #expect(presenter.summary(logged: logged, targets: targets) == (28, 280))
        #expect(interactor.playedHaptics.map { "\($0)" } == ["selection", "selection"])
        #expect(interactor.trackedEventNames == ["NutritionTargetChart_Day_Pressed", "NutritionTargetChart_Day_Pressed"])
    }
}
