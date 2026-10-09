//
//  EnergyBalancePresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The Energy Balance screen: calories eaten against calories burned.
///
/// `getDailyTotals` answers for every day in the range asked for, totalling zero where nothing was
/// logged. Taking those zeroes at face value made every untouched day an intake of 0 kcal — a bar
/// at the floor of the chart, a row claiming a full day's deficit, and a daily average dragged down
/// by every day the user never opened the app. That is what most of this file pins.
@MainActor
struct EnergyBalancePresenterTests {

    private final class Interactor: SpyGlobalInteractor, EnergyBalanceInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var draftMeal: MealLogModel?
        var tdee: Double = 3000
        /// Calories logged, by day key. Days not present here are answered as zero, as the real
        /// `MealLogManager` does.
        var caloriesByDay: [String: Double] = [:]

        func getDailyTotals(dayKey: String) throws -> DailyMacroTarget {
            DailyMacroTarget(
                calories: caloriesByDay[dayKey] ?? 0,
                proteinGrams: 0,
                carbGrams: 0,
                fatGrams: 0
            )
        }

        func getDailyTotals(startDayKey: String, endDayKey: String) throws -> [(dayKey: String, totals: DailyMacroTarget)] {
            guard let start = Date(dayKey: startDayKey), let end = Date(dayKey: endDayKey), start <= end else {
                return []
            }
            return try Date.dayKeys(from: start, to: end).map { (dayKey: $0, totals: try getDailyTotals(dayKey: $0)) }
        }

        func estimateTDEE(user: UserModel?) -> Double {
            tdee
        }

        var expenditureHistory: [ExpenditureEstimate] = []
    }

    private final class Router: EnergyBalanceRouter {
        private(set) var coachContexts: [CoachContext] = []
        func showCoach(context: CoachContext) { coachContexts.append(context) }
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var didShowAddMeal = false

        func showAddMealView(delegate: AddMealDelegate) {
            didShowAddMeal = true
        }
    }

    private struct Screen {
        let presenter: EnergyBalancePresenter
        let interactor: Interactor
        let router: Router
    }

    /// The day key `daysAgo` days back.
    private func dayKey(_ daysAgo: Int) -> String {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)?.dayKey ?? Date().dayKey
    }

    private func makeScreen(logged: [Int: Double] = [:], tdee: Double = 3000) -> Screen {
        let interactor = Interactor()
        interactor.tdee = tdee
        interactor.caloriesByDay = Dictionary(uniqueKeysWithValues: logged.map { (dayKey($0.key), $0.value) })
        let router = Router()
        return Screen(
            presenter: EnergyBalancePresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - Which days count

    /// The heart of it: a day with nothing logged is a day with no data, not a day of eating
    /// nothing.
    @Test("Test Days With Nothing Logged Are Left Out")
    func testDaysWithNothingLoggedAreLeftOut() {
        let screen = makeScreen(logged: [2: 2000, 1: 2200, 0: 2100])

        #expect(screen.presenter.entries.count == 3)
    }

    @Test("Test Nothing Logged At All Leaves The Screen Empty")
    func testNothingLoggedAtAllLeavesTheScreenEmpty() {
        let screen = makeScreen(logged: [:])

        #expect(screen.presenter.entries.isEmpty)
    }

    /// A day the user recorded as zero is indistinguishable from one they never opened, so it is
    /// treated as unlogged rather than as a fast.
    @Test("Test A Day Logged As Zero Is Treated As Unlogged")
    func testADayLoggedAsZeroIsTreatedAsUnlogged() {
        let screen = makeScreen(logged: [1: 0, 0: 2100])

        #expect(screen.presenter.entries.count == 1)
    }

    // MARK: - The chart

    /// Intake leads, because it is the series the bars and the Latest row describe; expenditure is
    /// the line drawn over them.
    @Test("Test Intake Leads And Expenditure Follows")
    func testIntakeLeadsAndExpenditureFollows() {
        let screen = makeScreen(logged: [0: 2100])

        #expect(screen.presenter.timeSeries.map(\.name) == ["Intake", "Expenditure"])
    }

    /// Expenditure is known for every day, so the line runs unbroken across days with no bar under
    /// it.
    @Test("Test Expenditure Covers Every Day, Intake Only The Logged Ones")
    func testExpenditureCoversEveryDayIntakeOnlyTheLoggedOnes() throws {
        let screen = makeScreen(logged: [1: 2200, 0: 2100])

        let intake = try #require(screen.presenter.timeSeries.first { $0.name == "Intake" })
        let expenditure = try #require(screen.presenter.timeSeries.first { $0.name == "Expenditure" })

        #expect(intake.data.count == 2)
        #expect(expenditure.data.count == 90)
    }

    @Test("Test Every Day Carries The Same Expenditure")
    func testEveryDayCarriesTheSameExpenditure() throws {
        let screen = makeScreen(logged: [0: 2100], tdee: 2750)

        let expenditure = try #require(screen.presenter.timeSeries.first { $0.name == "Expenditure" })

        #expect(expenditure.data.allSatisfy { $0.value == 2750 })
    }

    /// The expenditure side is the adaptive estimate where the engine has one, the last estimate
    /// after its history stops, and the formula before it starts.
    @Test("Test Expenditure Follows The Adaptive History")
    func testExpenditureFollowsTheAdaptiveHistory() throws {
        let interactor = Interactor()
        interactor.tdee = 3000
        interactor.caloriesByDay = [dayKey(0): 2100, dayKey(5): 2200, dayKey(20): 2300]
        let startOfToday = Calendar.current.startOfDay(for: .now)
        // Oldest first, ten days ago to yesterday, as the engine returns it.
        interactor.expenditureHistory = (1...10).reversed().map { daysAgo in
            ExpenditureEstimate(
                day: Calendar.current.date(byAdding: .day, value: -daysAgo, to: startOfToday) ?? startOfToday,
                kcal: 2600 + Double(daysAgo), source: .adaptive, isProvisional: false, trendWeightKg: 80,
                weeklyTrendChangeKg: 0, loggedDays: 28, weighInCount: 28, windowDays: 28, stepAdjustmentKcal: 0
            )
        }
        let presenter = EnergyBalancePresenter(interactor: interactor, router: Router())

        let byKey = Dictionary(uniqueKeysWithValues: presenter.entries.map { ($0.id, $0.expenditure) })
        // Five days ago is in the history; today is after it, so it carries the latest (one day
        // ago); twenty days ago is before it, so it is the formula.
        #expect(byKey[dayKey(5)] == 2605)
        #expect(byKey[dayKey(0)] == 2601)
        #expect(byKey[dayKey(20)] == 3000)
    }

    @Test("Test The Chart Plots What Was Logged")
    func testTheChartPlotsWhatWasLogged() throws {
        let screen = makeScreen(logged: [0: 2393])

        let intake = try #require(screen.presenter.timeSeries.first { $0.name == "Intake" })

        #expect(intake.data.first?.value == 2393)
    }

    // MARK: - The entries

    @Test("Test An Entry Records Both Sides Of The Day")
    func testAnEntryRecordsBothSidesOfTheDay() throws {
        let screen = makeScreen(logged: [0: 2100], tdee: 3000)

        let entry = try #require(screen.presenter.entries.first)

        #expect(entry.intake == 2100)
        #expect(entry.expenditure == 3000)
        #expect(entry.balance == 900)
    }

    @Test("Test A Deficit And A Surplus Read Differently")
    func testADeficitAndASurplusReadDifferently() throws {
        let deficit = makeScreen(logged: [0: 2100], tdee: 3000)
        let surplus = makeScreen(logged: [0: 3500], tdee: 3000)

        #expect(try #require(deficit.presenter.entries.first).balanceLabel.contains("deficit"))
        #expect(try #require(surplus.presenter.entries.first).balanceLabel.contains("surplus"))
    }

    @Test("Test Eating Exactly The Expenditure Is Balanced")
    func testEatingExactlyTheExpenditureIsBalanced() throws {
        let screen = makeScreen(logged: [0: 3000], tdee: 3000)

        #expect(try #require(screen.presenter.entries.first).balanceLabel == "Balanced")
    }

    /// The list reads newest first, as the other metric screens do.
    @Test("Test The List Reads Newest First")
    func testTheListReadsNewestFirst() {
        let screen = makeScreen(logged: [2: 2000, 1: 2200, 0: 2100])

        let dates = screen.presenter.entries.map(\.date)

        #expect(dates == dates.sorted(by: >))
    }

    // MARK: - The screen

    @Test("Test The Screen Is Configured As A Combo Chart In Calories")
    func testTheScreenIsConfiguredAsAComboChartInCalories() {
        let screen = makeScreen()

        #expect(screen.presenter.configuration.title == "Energy Balance")
        #expect(screen.presenter.configuration.chartType == .combo)
        #expect(screen.presenter.configuration.lineSeriesNames == ["Expenditure"])
        #expect(screen.presenter.configuration.unitText == "kcal")
    }

    /// Both series are plotted by QuickCharts, so the screen must not also supply a hand-drawn one.
    @Test("Test The Screen Has No Custom Chart")
    func testTheScreenHasNoCustomChart() {
        #expect(makeScreen().presenter.customChartView == nil)
    }

    @Test("Test Adding A Meal Opens The Logger")
    func testAddingAMealOpensTheLogger() {
        let screen = makeScreen()

        screen.presenter.onAddPressed()

        #expect(screen.router.didShowAddMeal)
    }

    /// With a meal already part-built, adding another asks what to do with it rather than silently
    /// discarding the draft.
    @Test("Test Adding A Meal With A Draft Open Does Not Start A New One")
    func testAddingAMealWithADraftOpenDoesNotStartANewOne() {
        let screen = makeScreen()
        screen.interactor.draftMeal = MealLogModel(
            authorId: "user-1",
            dayKey: dayKey(0),
            date: .now,
            items: []
        )

        screen.presenter.onAddMealPressed()

        #expect(!screen.router.didShowAddMeal)
    }
}
