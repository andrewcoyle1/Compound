//
//  AnalyticsNutritionPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The nutrition interactor double the three nutrition screens share.
///
/// `getDailyTotals` answers for every day in the range asked for, totalling zero where nothing was
/// logged — as the real `MealLogManager` does. That is what makes the window boundaries worth
/// testing: a screen that takes those zeroes at face value invents days of fasting.
@MainActor
final class AnalyticsNutritionInteractorDouble: SpyGlobalInteractor, NutritionAnalyticsInteractor {
    var userId: String? = "user-1"
    var draftMeal: MealLogModel?
    var totalsByDay: [String: DailyMacroTarget] = [:]
    var breakdownByDay: [String: DailyNutritionBreakdown] = [:]
    var target: DailyMacroTarget?
    var targetError: Error?
    private(set) var requestedDayKeys: [String] = []

    func getDailyTotals(dayKey: String) throws -> DailyMacroTarget {
        requestedDayKeys.append(dayKey)
        return totalsByDay[dayKey] ?? DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0)
    }

    func getDailyTotals(startDayKey: String, endDayKey: String) throws -> [(dayKey: String, totals: DailyMacroTarget)] {
        guard let start = Date(dayKey: startDayKey), let end = Date(dayKey: endDayKey), start <= end else { return [] }
        return Date.dayKeys(from: start, to: end).map { key in
            (dayKey: key, totals: totalsByDay[key] ?? DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0))
        }
    }

    func getDailyTarget(for date: Date, userId: String) async throws -> DailyMacroTarget? {
        if let targetError { throw targetError }
        return target
    }

    func getMeals(startDayKey: String, endDayKey: String) throws -> [MealLogModel] { [] }

    func getDailyNutritionBreakdown(dayKey: String) throws -> DailyNutritionBreakdown {
        breakdownByDay[dayKey] ?? .empty
    }

    func getDailyNutritionBreakdown(startDayKey: String, endDayKey: String) throws -> [(dayKey: String, breakdown: DailyNutritionBreakdown)] {
        guard let start = Date(dayKey: startDayKey), let end = Date(dayKey: endDayKey), start <= end else { return [] }
        return Date.dayKeys(from: start, to: end).compactMap { key in
            guard let breakdown = breakdownByDay[key] else { return nil }
            return (dayKey: key, breakdown: breakdown)
        }
    }
}

@MainActor
final class AnalyticsNutritionRouterDouble: NutritionAnalyticsRouter {
    let router: AnyRouter = TestRouting.anyRouter
    private(set) var shownMetrics: [NutritionMetric] = []
    private(set) var addedMealLogs: [MealLogModel] = []

    func showNutritionMetricDetailView(metric: NutritionMetric, delegate: NutritionMetricDetailDelegate, themeColor: Color?) {
        shownMetrics.append(metric)
    }

    func showAddMealView(delegate: AddMealDelegate) {
        addedMealLogs.append(delegate.mealLog)
    }
}

/// The Nutrition Analytics screen: today's totals against today's target, plus a week of macros.
@MainActor
struct AnalyticsNutritionOverviewTests {

    private struct Screen {
        let presenter: NutritionAnalyticsPresenter
        let interactor: AnalyticsNutritionInteractorDouble
        let router: AnalyticsNutritionRouterDouble
    }

    /// A fixed day well in the past, so a derivation that reaches for `Date()` instead of the day
    /// being shown answers for the wrong week and fails.
    private let shownDay = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 11, hour: 10)) ?? Date()

    private func dayKey(offsetFromShownDay offset: Int) -> String {
        (Calendar.current.date(byAdding: .day, value: offset, to: shownDay) ?? shownDay).dayKey
    }

    private func makeScreen() -> Screen {
        let interactor = AnalyticsNutritionInteractorDouble()
        let router = AnalyticsNutritionRouterDouble()
        let presenter = NutritionAnalyticsPresenter(interactor: interactor, router: router)
        presenter.selectedDate = shownDay
        return Screen(presenter: presenter, interactor: interactor, router: router)
    }

    private func totals(calories: Double, protein: Double = 0, carbs: Double = 0, fat: Double = 0) -> DailyMacroTarget {
        DailyMacroTarget(calories: calories, proteinGrams: protein, carbGrams: carbs, fatGrams: fat)
    }

    // MARK: - The day being shown

    /// The screen answers for the day the user is looking at. Reading today's totals while showing
    /// last Tuesday would put today's breakfast on last Tuesday's card.
    @Test("Test Totals Are Read For The Day Being Shown")
    func testTotalsAreReadForTheDayBeingShown() async {
        let screen = makeScreen()
        screen.interactor.totalsByDay = [dayKey(offsetFromShownDay: 0): totals(calories: 2150, protein: 160)]

        await screen.presenter.loadData()

        #expect(screen.presenter.caloriesCurrent == 2150)
        #expect(screen.presenter.proteinCurrent == 160)
        #expect(screen.presenter.dayKey == shownDay.dayKey)
    }

    /// The macros chart is the seven days ending on the day being shown — inclusive of that day and
    /// of the day six back, and nothing after it.
    @Test("Test The Macros Week Ends On The Day Being Shown")
    func testTheMacrosWeekEndsOnTheDayBeingShown() async {
        let screen = makeScreen()
        screen.interactor.totalsByDay = [
            dayKey(offsetFromShownDay: -6): totals(calories: 100),
            dayKey(offsetFromShownDay: 0): totals(calories: 700),
            dayKey(offsetFromShownDay: -7): totals(calories: 9999),
            dayKey(offsetFromShownDay: 1): totals(calories: 8888)
        ]

        await screen.presenter.loadData()

        #expect(screen.presenter.macrosLast7Days.count == 7)
        #expect(screen.presenter.macrosLast7Days.first?.calories == 100)
        #expect(screen.presenter.macrosLast7Days.last?.calories == 700)
        #expect(screen.presenter.macrosLast7Days.map(\.calories).reduce(0, +) == 800)
    }

    /// The average is over the seven days of the window, so a week with two days logged reads as a
    /// weekly average rather than as those two days' mean.
    @Test("Test The Weekly Average Is Over Seven Days")
    func testTheWeeklyAverageIsOverSevenDays() async {
        let screen = makeScreen()
        screen.interactor.totalsByDay = [
            dayKey(offsetFromShownDay: 0): totals(calories: 2100),
            dayKey(offsetFromShownDay: -1): totals(calories: 1400)
        ]

        await screen.presenter.loadData()

        #expect(screen.presenter.macrosAverageCalories == 500)
    }

    // MARK: - Targets

    /// Without a diet plan there is no target to draw against, and the chart falls back to a
    /// sensible ceiling rather than dividing by nothing.
    @Test("Test With No Plan There Is No Target")
    func testWithNoPlanThereIsNoTarget() async {
        let screen = makeScreen()

        await screen.presenter.loadData()

        #expect(screen.presenter.caloriesTarget == nil)
        #expect(screen.presenter.proteinTarget == nil)
        #expect(screen.presenter.caloriesMax == 2400)
    }

    @Test("Test A Plans Targets Are Shown")
    func testAPlansTargetsAreShown() async {
        let screen = makeScreen()
        screen.interactor.target = DailyMacroTarget(calories: 2400, proteinGrams: 180, carbGrams: 250, fatGrams: 70)

        await screen.presenter.loadData()

        #expect(screen.presenter.caloriesTarget == 2400)
        #expect(screen.presenter.proteinTarget == 180)
        #expect(screen.presenter.carbsTarget == 250)
        #expect(screen.presenter.fatTarget == 70)
    }

    /// The chart's ceiling has to clear whatever was actually eaten, or a day over target draws a
    /// bar past the end of its own axis.
    @Test("Test The Chart Ceiling Clears An Overshoot")
    func testTheChartCeilingClearsAnOvershoot() async {
        let screen = makeScreen()
        screen.interactor.target = DailyMacroTarget(calories: 2000, proteinGrams: 100, carbGrams: 200, fatGrams: 60)
        screen.interactor.totalsByDay = [dayKey(offsetFromShownDay: 0): totals(calories: 3500, protein: 90)]

        await screen.presenter.loadData()

        #expect(screen.presenter.caloriesMax == 3500)
        #expect(screen.presenter.proteinMax == 120)
    }

    /// A target that cannot be fetched leaves the screen without one rather than failing to load
    /// the totals beside it.
    @Test("Test A Failed Target Does Not Lose The Totals")
    func testAFailedTargetDoesNotLoseTheTotals() async {
        let screen = makeScreen()
        screen.interactor.targetError = URLError(.notConnectedToInternet)
        screen.interactor.totalsByDay = [dayKey(offsetFromShownDay: 0): totals(calories: 2150)]

        await screen.presenter.loadData()

        #expect(screen.presenter.caloriesTarget == nil)
        #expect(screen.presenter.caloriesCurrent == 2150)
    }

    /// Signed out there is no plan to ask for, so no target is requested at all.
    @Test("Test Signed Out There Is No Target")
    func testSignedOutThereIsNoTarget() async {
        let screen = makeScreen()
        screen.interactor.userId = nil
        screen.interactor.target = DailyMacroTarget(calories: 2400, proteinGrams: 180, carbGrams: 250, fatGrams: 70)

        await screen.presenter.loadData()

        #expect(screen.presenter.caloriesTarget == nil)
    }

    // MARK: - Breakdown cards

    /// A micronutrient nobody has logged reads as "--" rather than as a confident zero.
    @Test("Test An Unlogged Micronutrient Reads As Missing")
    func testAnUnloggedMicronutrientReadsAsMissing() {
        let screen = makeScreen()

        #expect(screen.presenter.formatBreakdown(nil, unit: "mg") == Format.placeholder)
        #expect(screen.presenter.formatBreakdown(0, unit: "mg") == Format.placeholder)
    }

    /// An amount of 100 or more is printed through `Int(_:)`, which traps on an infinity — and a
    /// meal logged before the amount screens sanitised what was typed can still hold one.
    @Test("Test A Micronutrient That Is Not A Number Reads As Missing")
    func testAMicronutrientThatIsNotANumberReadsAsMissing() {
        let screen = makeScreen()

        #expect(screen.presenter.formatBreakdown(.nan, unit: "mg") == Format.placeholder)
        #expect(screen.presenter.formatBreakdown(.infinity, unit: "mg") == Format.placeholder)
        #expect(screen.presenter.formatBreakdown(-.infinity, unit: "mg") == Format.placeholder)
    }

    /// Small amounts keep a decimal, large ones do not — a 0.7mg of B6 rounded to 1 is a 40%
    /// overstatement, while 2,400mg of sodium gains nothing from ".0".
    @Test("Test Small Amounts Keep A Decimal")
    func testSmallAmountsKeepADecimal() {
        let screen = makeScreen()

        #expect(screen.presenter.formatBreakdown(0.7, unit: "mg") == "0.7")
        #expect(screen.presenter.formatBreakdown(12, unit: "mg") == "12")
        #expect(screen.presenter.formatBreakdown(240, unit: "mg") == "240")
    }

    /// A breakdown chart with no target still needs a ceiling that clears the logged amount.
    @Test("Test A Breakdown Ceiling Clears What Was Logged")
    func testABreakdownCeilingClearsWhatWasLogged() {
        let screen = makeScreen()

        #expect(screen.presenter.breakdownChartMax(current: 30, defaultMax: 100) == 100)
        #expect(screen.presenter.breakdownChartMax(current: 200, defaultMax: 100) == 240)
        #expect(screen.presenter.breakdownChartMax(current: nil, defaultMax: 100) == 100)
    }

    /// The breakdown is read for the day being shown, and a day with nothing logged leaves the
    /// cards empty rather than carrying yesterday's.
    @Test("Test The Breakdown Follows The Day Being Shown")
    func testTheBreakdownFollowsTheDayBeingShown() async {
        let screen = makeScreen()
        var breakdown = DailyNutritionBreakdown.empty
        breakdown.fiberGrams = 28
        screen.interactor.breakdownByDay = [dayKey(offsetFromShownDay: 0): breakdown]

        await screen.presenter.loadData()

        #expect(screen.presenter.dailyBreakdown?.fiberGrams == 28)
    }

    // MARK: - Navigation

    /// Each card opens the detail screen for its own metric.
    @Test("Test Each Card Opens Its Own Metric")
    func testEachCardOpensItsOwnMetric() {
        let screen = makeScreen()

        screen.presenter.onMacrosPressed(themeColor: nil)
        screen.presenter.onCaloriesPressed(themeColor: nil)
        screen.presenter.onProteinPressed(themeColor: nil)
        screen.presenter.onFatPressed(themeColor: nil)
        screen.presenter.onCarbsPressed(themeColor: nil)
        screen.presenter.onBreakdownMetricPressed(.sodium, themeColor: nil)

        #expect(screen.router.shownMetrics == [.macros, .calories, .protein, .fat, .carbs, .sodium])
    }

    @Test("Test Appearing Is Tracked")
    func testAppearingIsTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["NutritionAnalyticsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["NutritionAnalyticsView_Disappear"])
    }
}

/// The detail screen behind a nutrition card: a year of one metric.
@MainActor
struct AnalyticsNutritionMetricDetailTests {

    private struct Screen {
        let presenter: NutritionMetricDetailPresenter
        let interactor: AnalyticsNutritionInteractorDouble
        let router: AnalyticsNutritionRouterDouble
    }

    /// Days back from today, since this screen asks for the year ending now.
    private func dayKey(_ daysAgo: Int) -> String {
        (Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()).dayKey
    }

    private func makeScreen(metric: NutritionMetric) -> Screen {
        let interactor = AnalyticsNutritionInteractorDouble()
        let router = AnalyticsNutritionRouterDouble()
        return Screen(
            presenter: NutritionMetricDetailPresenter(interactor: interactor, router: router, metric: metric),
            interactor: interactor,
            router: router
        )
    }

    private func totals(calories: Double, protein: Double = 0, carbs: Double = 0, fat: Double = 0) -> DailyMacroTarget {
        DailyMacroTarget(calories: calories, proteinGrams: protein, carbGrams: carbs, fatGrams: fat)
    }

    // MARK: - Which days become bars

    /// A day nobody logged is not a day of eating nothing: a bar at the floor reads as a fast the
    /// user never had.
    @Test("Test Unlogged Days Are Not Plotted As Zero")
    func testUnloggedDaysAreNotPlottedAsZero() async {
        let screen = makeScreen(metric: .calories)
        screen.interactor.totalsByDay = [dayKey(3): totals(calories: 2100), dayKey(1): totals(calories: 1900)]

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.count == 2)
    }

    /// A day outside the year the screen asks for is left off the chart.
    @Test("Test A Day Beyond The Year Is Left Out")
    func testADayBeyondTheYearIsLeftOut() async {
        let screen = makeScreen(metric: .calories)
        screen.interactor.totalsByDay = [dayKey(500): totals(calories: 2100), dayKey(2): totals(calories: 1900)]

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.count == 1)
    }

    /// Days run oldest first so the bars read left to right in time order.
    @Test("Test Days Run Oldest First")
    func testDaysRunOldestFirst() async {
        let screen = makeScreen(metric: .calories)
        screen.interactor.totalsByDay = [
            dayKey(1): totals(calories: 2100),
            dayKey(9): totals(calories: 1900),
            dayKey(4): totals(calories: 2000)
        ]

        await screen.presenter.onAppear()

        let dates = screen.presenter.entries.map(\.date)
        #expect(dates == dates.sorted())
    }

    // MARK: - Macros

    /// The macros screen stacks three series, each carrying that day's own grams.
    @Test("Test Macros Stack Protein Carbs And Fat")
    func testMacrosStackProteinCarbsAndFat() async {
        let screen = makeScreen(metric: .macros)
        screen.interactor.totalsByDay = [dayKey(1): totals(calories: 2100, protein: 150, carbs: 220, fat: 70)]

        await screen.presenter.onAppear()

        #expect(screen.presenter.timeSeries.map(\.name) == ["Protein", "Carbs", "Fat"])
        #expect(screen.presenter.timeSeries.map { $0.data.first?.value } == [150, 220, 70])
        #expect(screen.presenter.configuration.chartType == .stackedBar)
        #expect(screen.presenter.configuration.isMacrosChart)
    }

    /// A day whose macros are all zero is a day with nothing logged, however many calories the
    /// totals claim.
    @Test("Test A Day With No Macros Is Not A Macros Day")
    func testADayWithNoMacrosIsNotAMacrosDay() async {
        let screen = makeScreen(metric: .macros)
        screen.interactor.totalsByDay = [dayKey(1): totals(calories: 400)]

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.isEmpty)
    }

    /// The three macros are carried on the entry so a row can print all three at once.
    @Test("Test A Macros Row Carries All Three")
    func testAMacrosRowCarriesAllThree() async throws {
        let screen = makeScreen(metric: .macros)
        screen.interactor.totalsByDay = [dayKey(1): totals(calories: 2100, protein: 148, carbs: 214, fat: 69.7)]

        await screen.presenter.onAppear()
        let entry = try #require(screen.presenter.entries.first)

        #expect(entry.displayValue == "\(Format.grams(148)) P · \(Format.grams(214)) C · \(Format.grams(69.7)) F")
    }

    // MARK: - Single metrics

    /// A single macro plots its own grams, not the day's calories.
    @Test("Test Protein Plots Grams Of Protein")
    func testProteinPlotsGramsOfProtein() async throws {
        let screen = makeScreen(metric: .protein)
        screen.interactor.totalsByDay = [dayKey(1): totals(calories: 2100, protein: 150)]

        await screen.presenter.onAppear()

        #expect(try #require(screen.presenter.entries.first).value == 150)
        #expect(screen.presenter.configuration.chartType == .bar)
    }

    /// A micronutrient comes from the breakdown rather than the day's macro totals, and a day the
    /// breakdown knows nothing about is left off.
    @Test("Test A Micronutrient Comes From The Breakdown")
    func testAMicronutrientComesFromTheBreakdown() async throws {
        let screen = makeScreen(metric: .sodium)
        var breakdown = DailyNutritionBreakdown.empty
        breakdown.sodiumMg = 2400
        screen.interactor.breakdownByDay = [dayKey(1): breakdown]
        screen.interactor.totalsByDay = [dayKey(2): totals(calories: 2100, protein: 150)]

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.count == 1)
        #expect(try #require(screen.presenter.entries.first).value == 2400)
    }

    /// A metric recorded as zero on a day is not plotted: it means the foods logged carried no
    /// figure for it, not that the user consumed none.
    @Test("Test A Zero Reading Is Not Plotted")
    func testAZeroReadingIsNotPlotted() async {
        let screen = makeScreen(metric: .sodium)
        var breakdown = DailyNutritionBreakdown.empty
        breakdown.sodiumMg = 0
        screen.interactor.breakdownByDay = [dayKey(1): breakdown]

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.isEmpty)
    }

    /// The screen names the metric it is showing, in its title, its series and its empty state.
    @Test("Test The Screen Is Titled For Its Metric")
    func testTheScreenIsTitledForItsMetric() {
        let screen = makeScreen(metric: .fiber)

        #expect(screen.presenter.configuration.title == "Fiber")
        #expect(screen.presenter.configuration.seriesNames == ["Fiber"])
        #expect(screen.presenter.configuration.emptyStateMessage.contains("fiber"))
        #expect(screen.presenter.contributionSeries == nil)
    }

    // MARK: - Adding

    @Test("Test An Open Draft Is Offered Rather Than Replaced")
    func testAnOpenDraftIsOfferedRatherThanReplaced() {
        let screen = makeScreen(metric: .calories)
        screen.interactor.draftMeal = MealLogModel(mealId: "draft-1", authorId: "user-1", dayKey: Date().dayKey, date: Date(), items: [])

        screen.presenter.onAddPressed()

        #expect(screen.router.addedMealLogs.map(\.mealId) == ["draft-1"])
    }

    @Test("Test Signed Out Nothing Is Opened")
    func testSignedOutNothingIsOpened() {
        let screen = makeScreen(metric: .calories)
        screen.interactor.userId = nil

        screen.presenter.onAddPressed()

        #expect(screen.router.addedMealLogs.isEmpty)
    }
}

/// The weekly target grid at the top of the Analytics tab.
@MainActor
struct AnalyticsNutritionTargetChartTests {

    private final class Interactor: SpyGlobalInteractor, NutritionTargetChartInteractor {
        var currentDietPlan: DietPlan?
        var totalsByDay: [String: DailyMacroTarget] = [:]
        private(set) var requestedDayKeys: [String] = []

        func getDailyTotals(dayKey: String) throws -> DailyMacroTarget {
            requestedDayKeys.append(dayKey)
            return totalsByDay[dayKey] ?? DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0)
        }
    }

    private final class Router: NutritionTargetChartRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var preferredDietViewsFromSettings: [Bool] = []

        func showPreferredDietView(isFromSettings: Bool) {
            preferredDietViewsFromSettings.append(isFromSettings)
        }
    }

    private struct Screen {
        let presenter: NutritionTargetChartPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(plan: DietPlan? = nil) -> Screen {
        let interactor = Interactor()
        interactor.currentDietPlan = plan
        let router = Router()
        return Screen(
            presenter: NutritionTargetChartPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func plan(days: [DailyMacroTarget]) -> DietPlan {
        DietPlan(
            planId: "plan-1",
            userId: "user-1",
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            tdeeEstimate: 2500,
            preferredDiet: "Balanced",
            calorieFloor: "1800",
            trainingType: "Strength",
            calorieDistribution: "40/30/30",
            proteinIntake: "High",
            days: days
        )
    }

    // MARK: - The week

    /// The grid is a Monday-start week, so the column marked today has to be the same day the week
    /// was counted from — an off-by-one here highlights the wrong column and reads yesterday's
    /// target as today's.
    @Test("Test Todays Column Is Todays Day Of The Week")
    func testTodaysColumnIsTodaysDayOfTheWeek() {
        let screen = makeScreen()

        let columnDate = Calendar.current.date(
            byAdding: .day,
            value: screen.presenter.todayIndexMondayStart,
            to: screen.presenter.mondayStartOfCurrentWeek
        )

        #expect(columnDate.map { Calendar.current.isDateInToday($0) } == true)
    }

    /// The week starts on Monday whatever the device's first weekday is, because the labels under
    /// it are written Monday first.
    @Test("Test The Week Starts On A Monday")
    func testTheWeekStartsOnAMonday() {
        let screen = makeScreen()

        // Gregorian weekday numbering: Sunday is 1, Monday is 2.
        #expect(Calendar.current.component(.weekday, from: screen.presenter.mondayStartOfCurrentWeek) == 2)
        #expect(screen.presenter.mondayStartOfCurrentWeek <= Calendar.current.startOfDay(for: Date()))
    }

    /// Seven labels, Monday first, matching the seven columns they sit under.
    @Test("Test The Labels Run Monday To Sunday")
    func testTheLabelsRunMondayToSunday() {
        let screen = makeScreen()

        let symbols = Calendar.current.veryShortWeekdaySymbols
        #expect(screen.presenter.dayAbbrevs.count == 7)
        #expect(screen.presenter.dayAbbrevs.first == symbols[1])
        #expect(screen.presenter.dayAbbrevs.last == symbols[0])
    }

    // MARK: - Logged totals

    /// Each column is read for its own day of the current week, so a meal logged on Tuesday lands
    /// in Tuesday's cell.
    @Test("Test Each Column Reads Its Own Day")
    func testEachColumnReadsItsOwnDay() async throws {
        let screen = makeScreen()
        let wednesday = Calendar.current.date(byAdding: .day, value: 2, to: screen.presenter.mondayStartOfCurrentWeek) ?? Date()
        screen.interactor.totalsByDay = [wednesday.dayKey: DailyMacroTarget(calories: 2100, proteinGrams: 150, carbGrams: 200, fatGrams: 70)]

        await screen.presenter.loadCurrentWeekLoggedTotals()

        let loggedDays = try #require(screen.presenter.loggedDays)
        #expect(loggedDays.count == 7)
        #expect(loggedDays[2].calories == 2100)
        #expect(loggedDays[0].calories == 0)
    }

    /// Nothing is claimed about the week before it has been read. Seven zeroed days would say the
    /// user ate nothing all week, which is a different statement from not having looked yet.
    @Test("Test An Unloaded Week Claims Nothing")
    func testAnUnloadedWeekClaimsNothing() {
        let screen = makeScreen()

        #expect(screen.presenter.loggedDays == nil)
    }

    /// The plan's own seven days are the targets when there is a plan.
    @Test("Test A Plans Days Are The Targets")
    func testAPlansDaysAreTheTargets() {
        let days = (0..<7).map { DailyMacroTarget(calories: Double(2000 + $0), proteinGrams: 150, carbGrams: 200, fatGrams: 70) }
        let screen = makeScreen(plan: plan(days: days))

        #expect(screen.presenter.planDays?.map(\.calories) == days.map(\.calories))
    }

    /// The grid used to fill a missing plan with `DailyMacroTarget.mock`, drawing seven invented
    /// targets that read exactly like the user's own. People eat to these numbers, so there is
    /// nothing to draw until there is a plan.
    @Test("Test No Plan Invents No Targets")
    func testNoPlanInventsNoTargets() {
        let screen = makeScreen(plan: nil)

        #expect(screen.presenter.planDays == nil)
    }

    /// A plan that is not seven days long cannot be laid over a seven-column Monday-start week
    /// without printing one day's target under another, so it is treated as no plan rather than
    /// mis-assigned. No path that builds a plan produces one, so this is a malformed stored
    /// document.
    @Test("Test A Plan Of The Wrong Length Is Not Laid Over The Week")
    func testAPlanOfTheWrongLengthIsNotLaidOverTheWeek() {
        let days = (0..<3).map { _ in DailyMacroTarget(calories: 1234, proteinGrams: 150, carbGrams: 200, fatGrams: 70) }
        let screen = makeScreen(plan: plan(days: days))

        #expect(screen.presenter.planDays == nil)
    }

    /// The empty state is the only place in the app outside Settings that offers to build a plan,
    /// and it enters the questionnaire the way Settings does so it dismisses back here at the end
    /// instead of carrying on into onboarding.
    @Test("Test Creating A Plan Opens The Diet Questionnaire")
    func testCreatingAPlanOpensTheDietQuestionnaire() {
        let screen = makeScreen(plan: nil)

        screen.presenter.onCreatePlanPressed()

        #expect(screen.router.preferredDietViewsFromSettings == [true])
        #expect(screen.interactor.trackedEventNames.contains("NutritionTargetChart_CreatePlan_Pressed"))
    }

    // MARK: - Reading a cell

    /// Each metric reads its own field: a row showing carbs must not print the protein figure.
    @Test("Test Each Metric Reads Its Own Field")
    func testEachMetricReadsItsOwnField() {
        let screen = makeScreen()
        let day = DailyMacroTarget(calories: 2100, proteinGrams: 150, carbGrams: 220, fatGrams: 70)

        #expect(screen.presenter.value(for: .calories, day: day) == 2100)
        #expect(screen.presenter.value(for: .protein, day: day) == 150)
        #expect(screen.presenter.value(for: .carbs, day: day) == 220)
        #expect(screen.presenter.value(for: .fats, day: day) == 70)
    }

    /// The weekly totals used to read "15210" beside a flame and "1150P": calories now go through
    /// `Format.kcal` and the macros through `Format.grams`, like every other amount in the app.
    @Test("Test Calories Are Counted In Kcal And Macros In Grams")
    func testCaloriesAreCountedInKcalAndMacrosInGrams() {
        let screen = makeScreen()

        #expect(screen.presenter.amountText(15_210, for: .calories) == Format.kcal(15_210))
        #expect(screen.presenter.amountText(1_150, for: .protein) == Format.grams(1_150))
        #expect(screen.presenter.amountText(210, for: .carbs) == Format.grams(210))
        #expect(screen.presenter.amountText(70, for: .fats) == Format.grams(70))
    }

    /// Over target is said in words for VoiceOver, not left to the bar passing its tick.
    @Test("Test Going Over Target Is Said In Words")
    func testGoingOverTargetIsSaidInWords() {
        let screen = makeScreen()

        let over = screen.presenter.cellAccessibilityValue(logged: 180, target: 150, metric: .protein)
        let under = screen.presenter.cellAccessibilityValue(logged: 48, target: 150, metric: .protein)

        #expect(over.hasSuffix("over target"))
        #expect(under == "\(Format.grams(48)) of \(Format.grams(150))")
    }
}
