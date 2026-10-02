//
//  HabitsPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The Habits screen: how consistently the user trains, weighs in and logs food.
///
/// Each habit is shown as a thirty-cell contribution grid, filled column by column, three rows to a
/// column — so a cell's index is not its day offset, and the last cell is today. Getting that
/// mapping wrong shifts the whole grid without making it look broken, which is what these tests
/// guard.
///
/// Consistency is a question of days, not counts: weighing in twice on Monday is one day of the
/// habit, not two.
@MainActor
struct HabitsPresenterTests {

    private final class Interactor: SpyGlobalInteractor, HabitsInteractor {
        var auth: UserAuthInfo?
        var workoutSessions: [WorkoutSessionModel] = []
        var bodyMeasurements: [BodyMeasurementEntry] = []
        /// Calories logged by day key; days absent are answered as zero, as the real one does.
        var caloriesByDay: [String: Double] = [:]
        /// Whether a logged day also carries macros. The screen reads the macro total rather than
        /// the calorie total, so this is the switch the food-logging tests turn on and off.
        var logsMacros = true

        func getDailyTotals(startDayKey: String, endDayKey: String) throws -> [(dayKey: String, totals: DailyMacroTarget)] {
            guard let start = Date(dayKey: startDayKey), let end = Date(dayKey: endDayKey), start <= end else {
                return []
            }
            return Date.dayKeys(from: start, to: end).map { key in
                let calories = caloriesByDay[key] ?? 0
                // A rough but realistic split, so a logged day carries macros the way a real one does.
                let macroShare = logsMacros ? calories / 4 / 3 : 0
                return (dayKey: key, totals: DailyMacroTarget(
                    calories: calories,
                    proteinGrams: macroShare,
                    carbGrams: macroShare,
                    fatGrams: macroShare
                ))
            }
        }
    }

    private final class Router: HabitsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        func showScaleWeightView(delegate: ScaleWeightDelegate, themeColor: Color?) { shown.append("scaleWeight") }
        func showWeighInConsistencyView(delegate: WeighInConsistencyDelegate, themeColor: Color?) { shown.append("weighIn") }
        func showWorkoutView(delegate: WorkoutDelegate, themeColor: Color?) { shown.append("workout") }
        func showWorkoutConsistencyView(delegate: WorkoutConsistencyDelegate, themeColor: Color?) { shown.append("workoutConsistency") }
        func showFoodLoggingConsistencyView(delegate: FoodLoggingConsistencyDelegate, themeColor: Color?) { shown.append("foodLogging") }
        func showNutritionMetricDetailView(metric: NutritionMetric, delegate: NutritionMetricDetailDelegate, themeColor: Color?) {
            shown.append("nutritionMetric")
        }
    }

    private struct Screen {
        let presenter: HabitsPresenter
        let interactor: Interactor
        let router: Router
    }

    private let calendar = Calendar.current

    /// Midday `daysAgo` days back, so nothing drifts across a day boundary.
    private func date(_ daysAgo: Int) -> Date {
        let midday = calendar.startOfDay(for: .now).addingTimeInterval(12 * 3600)
        return calendar.date(byAdding: .day, value: -daysAgo, to: midday) ?? midday
    }

    private func session(id: String, daysAgo: Int, ended: Bool = true) -> WorkoutSessionModel {
        let day = date(daysAgo)
        return WorkoutSessionModel(
            id: id,
            authorId: "author-1",
            name: "Push Day",
            dateCreated: day,
            endedAt: ended ? day : nil,
            exercises: []
        )
    }

    private func weighIn(id: String, daysAgo: Int, weightKg: Double? = 72.0) -> BodyMeasurementEntry {
        let day = date(daysAgo)
        return BodyMeasurementEntry(
            id: id,
            authorId: "author-1",
            weightKg: weightKg,
            date: day,
            source: .manual,
            dateCreated: day
        )
    }

    private func makeScreen(
        sessions: [WorkoutSessionModel] = [],
        weighIns: [BodyMeasurementEntry] = [],
        logged: [Int: Double] = [:],
        logsMacros: Bool = true
    ) -> Screen {
        let interactor = Interactor()
        interactor.workoutSessions = sessions
        interactor.bodyMeasurements = weighIns
        interactor.logsMacros = logsMacros
        interactor.caloriesByDay = Dictionary(
            uniqueKeysWithValues: logged.map { (date($0.key).dayKey, $0.value) }
        )
        let router = Router()
        return Screen(
            presenter: HabitsPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - Workouts

    @Test("Test Finished Workouts In The Last Thirty Days Are Counted")
    func testFinishedWorkoutsInTheLastThirtyDaysAreCounted() {
        let screen = makeScreen(sessions: [
            session(id: "s1", daysAgo: 1),
            session(id: "s2", daysAgo: 10),
            session(id: "s3", daysAgo: 29)
        ])

        screen.presenter.loadWorkoutData()

        #expect(screen.presenter.workoutCountLast30Days == 3)
    }

    @Test("Test Workouts Older Than Thirty Days Are Left Out")
    func testWorkoutsOlderThanThirtyDaysAreLeftOut() {
        let screen = makeScreen(sessions: [
            session(id: "old", daysAgo: 45),
            session(id: "recent", daysAgo: 5)
        ])

        screen.presenter.loadWorkoutData()

        #expect(screen.presenter.workoutCountLast30Days == 1)
    }

    /// A workout in progress is not a workout done.
    @Test("Test Unfinished Workouts Are Left Out")
    func testUnfinishedWorkoutsAreLeftOut() {
        let screen = makeScreen(sessions: [
            session(id: "done", daysAgo: 1),
            session(id: "live", daysAgo: 0, ended: false)
        ])

        screen.presenter.loadWorkoutData()

        #expect(screen.presenter.workoutCountLast30Days == 1)
    }

    @Test("Test No Workouts Count As None")
    func testNoWorkoutsCountAsNone() {
        let screen = makeScreen()

        screen.presenter.loadWorkoutData()

        #expect(screen.presenter.workoutCountLast30Days == 0)
        #expect(screen.presenter.workoutCountThisWeek == 0)
    }

    // MARK: - The contribution grid

    /// Thirty cells, whatever the data — the grid is a fixed ten columns of three.
    @Test("Test The Grid Is Always Thirty Cells")
    func testTheGridIsAlwaysThirtyCells() {
        let empty = makeScreen()
        let full = makeScreen(sessions: (0..<30).map { session(id: "s\($0)", daysAgo: $0) })

        empty.presenter.loadWorkoutData()
        full.presenter.loadWorkoutData()

        #expect(empty.presenter.workoutContributionData.count == 30)
        #expect(full.presenter.workoutContributionData.count == 30)
    }

    @Test("Test An Empty Grid Is All Zeroes")
    func testAnEmptyGridIsAllZeroes() {
        let screen = makeScreen()

        screen.presenter.loadWorkoutData()

        #expect(screen.presenter.workoutContributionData.allSatisfy { $0 == 0 })
    }

    /// The grid runs to today, so training today fills its last cell. An off-by-one in the date
    /// mapping shows up here and nowhere else.
    @Test("Test Training Today Fills The Last Cell")
    func testTrainingTodayFillsTheLastCell() {
        let screen = makeScreen(sessions: [session(id: "today", daysAgo: 0)])

        screen.presenter.loadWorkoutData()

        #expect(screen.presenter.workoutContributionData.last == 1.0)
        #expect(screen.presenter.workoutContributionData.dropLast().allSatisfy { $0 == 0 })
    }

    @Test("Test Training Thirty Days Ago Fills The First Cell")
    func testTrainingThirtyDaysAgoFillsTheFirstCell() {
        let screen = makeScreen(sessions: [session(id: "oldest", daysAgo: 29)])

        screen.presenter.loadWorkoutData()

        #expect(screen.presenter.workoutContributionData.first == 1.0)
    }

    /// A day either had the habit or it did not; two workouts in a day do not fill two cells.
    @Test("Test Two Workouts In A Day Fill One Cell")
    func testTwoWorkoutsInADayFillOneCell() {
        let screen = makeScreen(sessions: [
            session(id: "morning", daysAgo: 1),
            session(id: "evening", daysAgo: 1)
        ])

        screen.presenter.loadWorkoutData()

        #expect(screen.presenter.workoutContributionData.filter { $0 == 1.0 }.count == 1)
        #expect(screen.presenter.workoutCountLast30Days == 2)
    }

    // MARK: - Weigh-ins

    @Test("Test Weigh-Ins Fill Their Own Grid")
    func testWeighInsFillTheirOwnGrid() {
        let screen = makeScreen(weighIns: [weighIn(id: "w1", daysAgo: 0)])

        screen.presenter.loadWeighInData()

        #expect(screen.presenter.weighInContributionData.count == 30)
        #expect(screen.presenter.weighInContributionData.last == 1.0)
    }

    /// An entry recording only a circumference is not a weigh-in.
    @Test("Test Entries Without A Weight Are Not Weigh-Ins")
    func testEntriesWithoutAWeightAreNotWeighIns() {
        let screen = makeScreen(weighIns: [weighIn(id: "waist", daysAgo: 0, weightKg: nil)])

        screen.presenter.loadWeighInData()

        #expect(screen.presenter.weighInContributionData.allSatisfy { $0 == 0 })
    }

    @Test("Test Weighing In Twice In A Day Counts Once")
    func testWeighingInTwiceInADayCountsOnce() {
        let screen = makeScreen(weighIns: [
            weighIn(id: "morning", daysAgo: 1),
            weighIn(id: "evening", daysAgo: 1)
        ])

        screen.presenter.loadWeighInData()

        #expect(screen.presenter.weighInContributionData.filter { $0 == 1.0 }.count == 1)
    }

    // MARK: - Food logging

    @Test("Test Days With Food Logged Fill The Grid")
    func testDaysWithFoodLoggedFillTheGrid() {
        let screen = makeScreen(logged: [0: 2100, 1: 2200])

        screen.presenter.loadFoodLoggingData()

        #expect(screen.presenter.foodLoggingContributionData.count == 30)
        #expect(screen.presenter.foodLoggingContributionData.filter { $0 == 1.0 }.count == 2)
    }

    /// A day with nothing logged is a day the habit was not kept — the same distinction Energy
    /// Balance needed.
    @Test("Test A Day With Nothing Logged Does Not Count")
    func testADayWithNothingLoggedDoesNotCount() {
        let screen = makeScreen(logged: [:])

        screen.presenter.loadFoodLoggingData()

        #expect(screen.presenter.foodLoggingContributionData.allSatisfy { $0 == 0 })
    }

    /// The habit is judged on the macro total, not the calorie total. A day whose entries carry
    /// calories but no macros — an unparsed label, say — does not fill a cell.
    @Test("Test A Day With Calories But No Macros Does Not Count")
    func testADayWithCaloriesButNoMacrosDoesNotCount() {
        let screen = makeScreen(logged: [0: 2100], logsMacros: false)

        screen.presenter.loadFoodLoggingData()

        #expect(screen.presenter.foodLoggingContributionData.allSatisfy { $0 == 0 })
    }

    // MARK: - Loading

    @Test("Test The First Task Loads All Three Habits")
    func testTheFirstTaskLoadsAllThreeHabits() async {
        let screen = makeScreen(
            sessions: [session(id: "s1", daysAgo: 1)],
            weighIns: [weighIn(id: "w1", daysAgo: 1)],
            logged: [1: 2100]
        )

        await screen.presenter.onFirstTask()

        #expect(screen.presenter.workoutContributionData.count == 30)
        #expect(screen.presenter.weighInContributionData.count == 30)
        #expect(screen.presenter.foodLoggingContributionData.count == 30)
    }

    // MARK: - Navigation

    @Test("Test Each Habit Opens Its Own Screen")
    func testEachHabitOpensItsOwnScreen() {
        let screen = makeScreen()

        screen.presenter.onWeighInPressed(themeColor: nil)
        screen.presenter.onWorkoutsPressed(themeColor: nil)
        screen.presenter.onFoodLoggingPressed(themeColor: nil)

        #expect(screen.router.shown.count == 3)
        #expect(Set(screen.router.shown).count == 3)
    }
}
