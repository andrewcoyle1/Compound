//
//  AnalyticsConsistencyPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// Shared fixtures for the three "how often did you" screens.
///
/// Every date here is fixed and none of them is today, so a derivation that reaches for `Date()`
/// instead of the day it is describing fails rather than passing by coincidence.
@MainActor
enum AnalyticsConsistencyFixture {

    /// Midday on a fixed day in March 2026 — comfortably inside the year these screens ask for and
    /// comfortably not today.
    static func date(day: Int, month: Int = 3, year: Int = 2026, hour: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    static func weighIn(id: String, kilograms: Double?, day: Int, deleted: Bool = false, waistCm: Double? = nil) -> BodyMeasurementEntry {
        let when = date(day: day)
        return BodyMeasurementEntry(
            id: id,
            authorId: "author-1",
            weightKg: kilograms,
            waistCircumference: waistCm,
            date: when,
            deletedAt: deleted ? when : nil
        )
    }

    static func set(id: String, reps: Int?, weightKg: Double?, isWarmup: Bool = false, completed: Bool = true) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id,
            authorId: "author-1",
            index: 1,
            reps: reps,
            weightKg: weightKg,
            isWarmup: isWarmup,
            completedAt: completed ? date(day: 1) : nil,
            dateCreated: date(day: 1)
        )
    }

    static func session(
        id: String,
        name: String = "Push Day",
        day: Int,
        ended: Bool = true,
        isRestDay: Bool = false,
        sets: [WorkoutSetModel] = []
    ) -> WorkoutSessionModel {
        let when = date(day: day)
        return WorkoutSessionModel(
            id: id,
            authorId: "author-1",
            name: name,
            dateCreated: when,
            endedAt: ended ? when : nil,
            exercises: sets.isEmpty ? [] : [
                WorkoutExerciseModel(
                    id: "we-\(id)",
                    authorId: "author-1",
                    templateId: "template-1",
                    name: "Bench Press",
                    trackingMode: .weightReps,
                    index: 1,
                    sets: sets
                )
            ],
            isRestDay: isRestDay
        )
    }
}

/// The weigh-in consistency grid: one square per day a weight was recorded.
@MainActor
struct AnalyticsWeighInConsistencyTests {

    private final class Interactor: SpyGlobalInteractor, ScaleWeightInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var bodyMeasurements: [BodyMeasurementEntry] = []
        private(set) var saved: [BodyMeasurementEntry] = []
        var saveError: Error?

        func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws {
            if let saveError { throw saveError }
            saved.append(bodyMeasurement)
        }

        func syncWeightFromHealthKit() async { }
    }

    private final class Router: ScaleWeightRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var didShowLogWeight = false

        func showLogWeightView() { didShowLogWeight = true }
    }

    private struct Screen {
        let presenter: WeighInConsistencyPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(
        measurements: [BodyMeasurementEntry] = [],
        unit: WeightUnitPreference = .kilograms
    ) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = UserModel(userId: "user-1", submittedWeightUnitPreference: unit)
        interactor.bodyMeasurements = measurements
        let router = Router()
        return Screen(
            presenter: WeighInConsistencyPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - What counts as a weigh-in

    /// A day the user measured their waist but did not stand on the scale is not a weigh-in. It
    /// would otherwise shade a square on a grid that exists to say how often they weigh themselves.
    @Test("Test An Entry Without A Weight Is Not A Weigh In")
    func testAnEntryWithoutAWeightIsNotAWeighIn() async {
        let screen = makeScreen(measurements: [
            AnalyticsConsistencyFixture.weighIn(id: "weighed", kilograms: 82, day: 4),
            AnalyticsConsistencyFixture.weighIn(id: "waist-only", kilograms: nil, day: 5, waistCm: 80)
        ])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.map(\.id) == ["weighed"])
    }

    /// A weigh-in the user deleted must stop counting, or the grid keeps crediting them for it.
    @Test("Test A Deleted Weigh In Stops Counting")
    func testADeletedWeighInStopsCounting() async {
        let screen = makeScreen(measurements: [
            AnalyticsConsistencyFixture.weighIn(id: "live", kilograms: 82, day: 4),
            AnalyticsConsistencyFixture.weighIn(id: "gone", kilograms: 99, day: 5, deleted: true)
        ])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.map(\.id) == ["live"])
    }

    /// The grid is fed one point per weigh-in, each worth one, on the day it was recorded — not on
    /// the day the screen was opened.
    @Test("Test Each Weigh In Is One Point On Its Own Day")
    func testEachWeighInIsOnePointOnItsOwnDay() async throws {
        let screen = makeScreen(measurements: [
            AnalyticsConsistencyFixture.weighIn(id: "a", kilograms: 82, day: 4),
            AnalyticsConsistencyFixture.weighIn(id: "b", kilograms: 81.5, day: 6)
        ])

        await screen.presenter.onAppear()
        let series = try #require(screen.presenter.contributionSeries)

        #expect(series.data.count == 2)
        #expect(series.data.allSatisfy { $0.value == 1 })
        #expect(series.data.map(\.date).sorted() == [
            AnalyticsConsistencyFixture.date(day: 4),
            AnalyticsConsistencyFixture.date(day: 6)
        ])
    }

    /// With nothing logged there is no grid at all, rather than an empty one implying a run of
    /// missed days.
    @Test("Test No Weigh Ins Means No Grid")
    func testNoWeighInsMeansNoGrid() async {
        let screen = makeScreen()

        await screen.presenter.onAppear()

        #expect(screen.presenter.contributionSeries == nil)
        #expect(screen.presenter.entries.isEmpty)
    }

    // MARK: - Units

    /// Weight is stored in kilograms. A user who asked for pounds must see pounds in the rows and
    /// the same unit on the axis, or the screen quietly reports someone else's bodyweight.
    @Test("Test Pounds Users See Pounds")
    func testPoundsUsersSeePounds() async throws {
        let screen = makeScreen(
            measurements: [AnalyticsConsistencyFixture.weighIn(id: "a", kilograms: 100, day: 4)],
            unit: .pounds
        )

        await screen.presenter.onAppear()
        let entry = try #require(screen.presenter.entries.first)

        #expect(screen.presenter.displayValue(for: entry) == "220.5")
        #expect(screen.presenter.configuration.yAxisSuffix == " lb")
    }

    @Test("Test Kilogram Users See The Stored Number")
    func testKilogramUsersSeeTheStoredNumber() async throws {
        let screen = makeScreen(measurements: [AnalyticsConsistencyFixture.weighIn(id: "a", kilograms: 82.4, day: 4)])

        await screen.presenter.onAppear()
        let entry = try #require(screen.presenter.entries.first)

        #expect(screen.presenter.displayValue(for: entry) == "82.4")
    }

    // MARK: - Deleting

    /// A weigh-in shares its entry with any circumferences measured the same day, so deleting the
    /// weight must leave those alone.
    @Test("Test Deleting A Weigh In Keeps The Days Other Measurements")
    func testDeletingAWeighInKeepsTheDaysOtherMeasurements() async throws {
        let screen = makeScreen(measurements: [
            AnalyticsConsistencyFixture.weighIn(id: "day", kilograms: 82, day: 4, waistCm: 80)
        ])
        await screen.presenter.onAppear()
        let entry = try #require(screen.presenter.entries.first)

        await screen.presenter.onDeleteEntry(entry)

        #expect(screen.interactor.saved.first?.weightKg == nil)
        #expect(screen.interactor.saved.first?.waistCircumference == 80)
    }

    /// A delete that fails leaves the row in place. The alert it raises goes through a
    /// `GlobalRouter` extension method, which a double cannot intercept, so the state is what is
    /// asserted here.
    @Test("Test A Failed Delete Keeps The Weigh In")
    func testAFailedDeleteKeepsTheWeighIn() async throws {
        let screen = makeScreen(measurements: [AnalyticsConsistencyFixture.weighIn(id: "a", kilograms: 82, day: 4)])
        await screen.presenter.onAppear()
        screen.interactor.saveError = URLError(.timedOut)
        let entry = try #require(screen.presenter.entries.first)

        await screen.presenter.onDeleteEntry(entry)

        #expect(screen.presenter.entries.map(\.id) == ["a"])
    }

    @Test("Test Adding Opens The Weight Logger")
    func testAddingOpensTheWeightLogger() {
        let screen = makeScreen()

        screen.presenter.onAddPressed()

        #expect(screen.router.didShowLogWeight)
    }

    /// The grid replaces the line chart on this screen, so there must be no series behind it.
    @Test("Test The Screen Is A Grid Rather Than A Chart")
    func testTheScreenIsAGridRatherThanAChart() {
        let screen = makeScreen(measurements: [AnalyticsConsistencyFixture.weighIn(id: "a", kilograms: 82, day: 4)])

        #expect(screen.presenter.timeSeries.isEmpty)
        #expect(screen.presenter.configuration.title == "Weigh In")
        #expect(screen.presenter.supportsDeletion)
    }
}

/// The workout consistency grid: one square per completed workout.
@MainActor
struct AnalyticsWorkoutConsistencyTests {

    private final class Interactor: SpyGlobalInteractor, WorkoutInteractor {
        var auth: UserAuthInfo?
        var workoutSessions: [WorkoutSessionModel] = []
    }

    private final class Router: WorkoutRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var didShowWorkouts = false

        func showWorkoutsView(delegate: WorkoutsDelegate) { didShowWorkouts = true }
    }

    private struct Screen {
        let presenter: WorkoutConsistencyPresenter
        let router: Router
    }

    private func makeScreen(sessions: [WorkoutSessionModel] = []) -> Screen {
        let interactor = Interactor()
        interactor.workoutSessions = sessions
        let router = Router()
        return Screen(
            presenter: WorkoutConsistencyPresenter(interactor: interactor, router: router),
            router: router
        )
    }

    // MARK: - What counts as a workout

    /// A workout the user is still in the middle of has not happened yet. Counting it shades
    /// today's square before a single set is finished.
    @Test("Test A Workout In Progress Does Not Count")
    func testAWorkoutInProgressDoesNotCount() async {
        let screen = makeScreen(sessions: [
            AnalyticsConsistencyFixture.session(id: "done", day: 4),
            AnalyticsConsistencyFixture.session(id: "in-progress", day: 5, ended: false)
        ])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.map(\.id) == ["done"])
    }

    /// Rest days are written ahead of time by the training mesocycle, already marked as ended and
    /// dated into the future. Counted as workouts they put tomorrow at the top of the history as a
    /// zero-set session and shade squares for days that have not happened.
    @Test("Test A Rest Day Is Not A Workout")
    func testARestDayIsNotAWorkout() async {
        let screen = makeScreen(sessions: [
            AnalyticsConsistencyFixture.session(id: "real", day: 4, sets: [AnalyticsConsistencyFixture.set(id: "s1", reps: 8, weightKg: 80)]),
            AnalyticsConsistencyFixture.session(id: "rest", name: "Rest", day: 28, isRestDay: true)
        ])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.map(\.id) == ["real"])
    }

    /// Warm-up sets are not working sets: counting them inflates both the set count and the volume
    /// a user reads as their session's effort.
    @Test("Test Warm Up Sets Are Left Out Of The Count And The Volume")
    func testWarmUpSetsAreLeftOutOfTheCountAndTheVolume() async throws {
        let screen = makeScreen(sessions: [
            AnalyticsConsistencyFixture.session(id: "s", day: 4, sets: [
                AnalyticsConsistencyFixture.set(id: "warm", reps: 10, weightKg: 40, isWarmup: true),
                AnalyticsConsistencyFixture.set(id: "work", reps: 5, weightKg: 100)
            ])
        ])

        await screen.presenter.onAppear()
        let entry = try #require(screen.presenter.entries.first)

        #expect(entry.sets == 1)
        #expect(entry.volumeKg == 500)
    }

    /// A bodyweight set has no weight to multiply, so it counts as a set with no volume rather
    /// than dropping out of the session entirely.
    @Test("Test A Set Without A Weight Still Counts As A Set")
    func testASetWithoutAWeightStillCountsAsASet() async throws {
        let screen = makeScreen(sessions: [
            AnalyticsConsistencyFixture.session(id: "s", day: 4, sets: [
                AnalyticsConsistencyFixture.set(id: "bw", reps: 12, weightKg: nil)
            ])
        ])

        await screen.presenter.onAppear()
        let entry = try #require(screen.presenter.entries.first)

        #expect(entry.sets == 1)
        #expect(entry.volumeKg == 0)
    }

    /// The history reads newest first, and a workout is dated by when it ended.
    @Test("Test Workouts Read Newest First")
    func testWorkoutsReadNewestFirst() async {
        let screen = makeScreen(sessions: [
            AnalyticsConsistencyFixture.session(id: "older", day: 4),
            AnalyticsConsistencyFixture.session(id: "newer", day: 9)
        ])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.map(\.id) == ["newer", "older"])
        #expect(screen.presenter.entries.first?.date == AnalyticsConsistencyFixture.date(day: 9))
    }

    /// Two sessions on one day are two workouts — the grid's callout says "2 workouts" and the
    /// square shades darker for it.
    @Test("Test Two Workouts In A Day Are Two Points")
    func testTwoWorkoutsInADayAreTwoPoints() async throws {
        let screen = makeScreen(sessions: [
            AnalyticsConsistencyFixture.session(id: "morning", day: 4),
            AnalyticsConsistencyFixture.session(id: "evening", day: 4)
        ])

        await screen.presenter.onAppear()
        let series = try #require(screen.presenter.contributionSeries)

        #expect(series.data.count == 2)
        #expect(series.data.allSatisfy { $0.value == 1 })
    }

    @Test("Test No Completed Workouts Means No Grid")
    func testNoCompletedWorkoutsMeansNoGrid() async {
        let screen = makeScreen(sessions: [AnalyticsConsistencyFixture.session(id: "in-progress", day: 4, ended: false)])

        await screen.presenter.onAppear()

        #expect(screen.presenter.contributionSeries == nil)
    }

    /// Consistency is built from logged sessions, so the way to add one is to train.
    @Test("Test Adding Opens The Workouts List")
    func testAddingOpensTheWorkoutsList() {
        let screen = makeScreen()

        screen.presenter.onAddPressed()

        #expect(screen.router.didShowWorkouts)
        #expect(screen.presenter.configuration.addActionTitle == "Start Workout")
    }
}

/// The food-logging consistency grid: one square per day with food logged.
@MainActor
struct AnalyticsFoodLoggingConsistencyTests {

    private final class Interactor: SpyGlobalInteractor, NutritionAnalyticsInteractor {
        var userId: String? = "user-1"
        var draftMeal: MealLogModel?
        /// Totals by day key. A day absent is answered as zero, as the real `MealLogManager` does.
        var totalsByDay: [String: DailyMacroTarget] = [:]
        private(set) var requestedRanges: [(String, String)] = []

        func getDailyTotals(dayKey: String) throws -> DailyMacroTarget {
            totalsByDay[dayKey] ?? DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0)
        }

        func getDailyTotals(startDayKey: String, endDayKey: String) throws -> [(dayKey: String, totals: DailyMacroTarget)] {
            requestedRanges.append((startDayKey, endDayKey))
            guard let start = Date(dayKey: startDayKey), let end = Date(dayKey: endDayKey), start <= end else { return [] }
            return try Date.dayKeys(from: start, to: end).map { (dayKey: $0, totals: try getDailyTotals(dayKey: $0)) }
        }

        func getDailyTarget(for date: Date, userId: String) async throws -> DailyMacroTarget? { nil }

        func getMeals(startDayKey: String, endDayKey: String) throws -> [MealLogModel] { [] }

        func getDailyNutritionBreakdown(dayKey: String) throws -> DailyNutritionBreakdown {
            DailyNutritionBreakdown.empty
        }

        func getDailyNutritionBreakdown(startDayKey: String, endDayKey: String) throws -> [(dayKey: String, breakdown: DailyNutritionBreakdown)] {
            []
        }
    }

    private final class Router: NutritionAnalyticsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var addedMealLogs: [MealLogModel] = []

        func showNutritionMetricDetailView(metric: NutritionMetric, delegate: NutritionMetricDetailDelegate, themeColor: Color?) { }
        func showAddMealView(delegate: AddMealDelegate) { addedMealLogs.append(delegate.mealLog) }
    }

    private struct Screen {
        let presenter: FoodLoggingConsistencyPresenter
        let interactor: Interactor
        let router: Router
    }

    /// Days back from today, since this screen asks for the year up to now.
    private func dayKey(_ daysAgo: Int) -> String {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())?.dayKey ?? Date().dayKey
    }

    private func makeScreen(logged: [Int: DailyMacroTarget] = [:]) -> Screen {
        let interactor = Interactor()
        interactor.totalsByDay = Dictionary(uniqueKeysWithValues: logged.map { (dayKey($0.key), $0.value) })
        let router = Router()
        return Screen(
            presenter: FoodLoggingConsistencyPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func meal(protein: Double = 40, carbs: Double = 60, fat: Double = 20, calories: Double = 2000) -> DailyMacroTarget {
        DailyMacroTarget(calories: calories, proteinGrams: protein, carbGrams: carbs, fatGrams: fat)
    }

    // MARK: - Which days count

    /// A day nobody logged anything on answers as zero, not as a day of eating nothing. Taking it
    /// at face value would shade every untouched day of the year as logged.
    @Test("Test A Day With Nothing Logged Is Not A Logged Day")
    func testADayWithNothingLoggedIsNotALoggedDay() async {
        let screen = makeScreen(logged: [3: meal(), 1: meal()])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.count == 2)
    }

    /// Both endpoints of the year the screen asks for are included, so the day exactly a year back
    /// and today both count.
    @Test("Test The Window Runs From A Year Ago Through Today")
    func testTheWindowRunsFromAYearAgoThroughToday() async {
        let daysInWindow = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date(),
            to: Date()
        ).day ?? 365
        let screen = makeScreen(logged: [daysInWindow: meal(), 0: meal()])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.count == 2)
    }

    /// A day outside the year asked for is not shown, however much was logged on it.
    @Test("Test A Day Beyond The Window Is Left Out")
    func testADayBeyondTheWindowIsLeftOut() async {
        let screen = makeScreen(logged: [500: meal(), 2: meal()])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.count == 1)
    }

    /// A water-only day — calories recorded with no macros behind them — is not a day of food
    /// logging.
    @Test("Test A Day With Calories But No Macros Is Not Logged")
    func testADayWithCaloriesButNoMacrosIsNotLogged() async {
        let screen = makeScreen(logged: [2: DailyMacroTarget(calories: 120, proteinGrams: 0, carbGrams: 0, fatGrams: 0)])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.isEmpty)
    }

    /// One square per day, worth one, whatever was eaten — the grid counts days, not calories.
    @Test("Test Every Logged Day Is Worth One Square")
    func testEveryLoggedDayIsWorthOneSquare() async throws {
        let screen = makeScreen(logged: [3: meal(calories: 1200), 2: meal(calories: 3400)])

        await screen.presenter.onAppear()
        let series = try #require(screen.presenter.contributionSeries)

        #expect(series.data.map(\.value) == [1, 1])
    }

    @Test("Test Nothing Logged Means No Grid")
    func testNothingLoggedMeansNoGrid() async {
        let screen = makeScreen()

        await screen.presenter.onAppear()

        #expect(screen.presenter.contributionSeries == nil)
    }

    /// The rows read oldest first so the chart under them runs left to right.
    @Test("Test Days Are Ordered Oldest First")
    func testDaysAreOrderedOldestFirst() async {
        let screen = makeScreen(logged: [5: meal(), 1: meal(), 3: meal()])

        await screen.presenter.onAppear()

        let dates = screen.presenter.entries.map(\.date)
        #expect(dates == dates.sorted())
    }

    // MARK: - Adding

    /// A part-built meal is offered back rather than thrown away, the way the food search screen
    /// does it.
    @Test("Test An Open Draft Is Offered Rather Than Replaced")
    func testAnOpenDraftIsOfferedRatherThanReplaced() {
        let screen = makeScreen()
        let draft = MealLogModel(mealId: "draft-1", authorId: "user-1", dayKey: dayKey(0), date: Date(), items: [])
        screen.interactor.draftMeal = draft

        screen.presenter.onAddPressed()

        #expect(screen.router.addedMealLogs.map(\.mealId) == ["draft-1"])
    }

    @Test("Test With No Draft A New Meal Is Started For Today")
    func testWithNoDraftANewMealIsStartedForToday() {
        let screen = makeScreen()

        screen.presenter.onAddPressed()

        #expect(screen.router.addedMealLogs.first?.dayKey == Date().dayKey)
        #expect(screen.router.addedMealLogs.first?.authorId == "user-1")
    }

    /// Signed out there is nobody to attribute a meal to, so nothing is opened.
    @Test("Test Signed Out Nothing Is Opened")
    func testSignedOutNothingIsOpened() {
        let screen = makeScreen()
        screen.interactor.userId = nil

        screen.presenter.onAddPressed()

        #expect(screen.router.addedMealLogs.isEmpty)
    }

    @Test("Test The Screen Is A Grid Rather Than A Chart")
    func testTheScreenIsAGridRatherThanAChart() {
        let screen = makeScreen()

        #expect(screen.presenter.timeSeries.isEmpty)
        #expect(screen.presenter.configuration.title == "Food Logging")
        #expect(screen.presenter.supportsDeletion == false)
    }
}
