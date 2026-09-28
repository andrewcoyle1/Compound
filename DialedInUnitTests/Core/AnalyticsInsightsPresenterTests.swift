//
//  AnalyticsInsightsPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The Insights & Analytics screen: five summary cards, each a week of something derived from
/// somewhere else in the app.
///
/// Every card is a figure plus a sparkline, and each one is the headline a user reads without
/// opening the screen behind it — so a card that silently shows nothing, or shows the right number
/// in the wrong unit, is worse than no card.
@MainActor
struct AnalyticsInsightsPresenterTests {

    private final class Interactor: SpyGlobalInteractor, InsightsAndAnalyticsInteractor {
        var auth: UserAuthInfo?
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var bodyMeasurements: [BodyMeasurementEntry] = []
        var currentGoal: WeightGoal?
        var workoutSessions: [WorkoutSessionModel] = []
        var totalsByDay: [String: DailyMacroTarget] = [:]
        var tdee: Double = 3000

        func getDailyTotals(dayKey: String) throws -> DailyMacroTarget {
            totalsByDay[dayKey] ?? DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0)
        }

        func estimateTDEE(user: UserModel?) -> Double { tdee }
    }

    private final class Router: InsightsAndAnalyticsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        func showWeightTrendView(delegate: WeightTrendDelegate, themeColor: Color?) { shown.append("weightTrend") }
        func showGoalProgressView(delegate: GoalProgressDelegate, themeColor: Color?) { shown.append("goalProgress") }
        func showEnergyBalanceView(delegate: EnergyBalanceDelegate, themeColor: Color?) { shown.append("energyBalance") }
        func showWorkoutView(delegate: WorkoutDelegate, themeColor: Color?) { shown.append("workouts") }
        func showExpenditureDetailView(delegate: ExpenditureDetailDelegate, themeColor: Color?) { shown.append("expenditure") }
    }

    private struct Screen {
        let presenter: InsightsAndAnalyticsPresenter
        let interactor: Interactor
        let router: Router
    }

    /// Workout dates are fixed and are not today, so anything that quietly uses "now" for a session
    /// date is visible.
    private func date(day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: day, hour: 17)) ?? Date()
    }

    /// The intake card is the seven days ending today, so its fixtures are keyed off today.
    private func dayKey(_ daysAgo: Int) -> String {
        (Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()).dayKey
    }

    private func makeScreen(
        measurements: [BodyMeasurementEntry] = [],
        sessions: [WorkoutSessionModel] = [],
        goal: WeightGoal? = nil,
        logged: [Int: Double] = [:],
        tdee: Double = 3000,
        weightUnit: WeightUnitPreference = .kilograms
    ) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = UserModel(userId: "user-1", submittedWeightUnitPreference: weightUnit)
        interactor.bodyMeasurements = measurements
        interactor.workoutSessions = sessions
        interactor.currentGoal = goal
        interactor.tdee = tdee
        interactor.totalsByDay = Dictionary(uniqueKeysWithValues: logged.map {
            (dayKey($0.key), DailyMacroTarget(calories: $0.value, proteinGrams: 0, carbGrams: 0, fatGrams: 0))
        })
        let router = Router()
        return Screen(
            presenter: InsightsAndAnalyticsPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func weighIn(kilograms: Double, day: Int, deleted: Bool = false) -> BodyMeasurementEntry {
        let when = date(day: day)
        return BodyMeasurementEntry(
            authorId: "author-1",
            weightKg: kilograms,
            date: when,
            deletedAt: deleted ? when : nil
        )
    }

    private func session(id: String, day: Int, workingSets: Int, ended: Bool = true, isRestDay: Bool = false) -> WorkoutSessionModel {
        let when = date(day: day)
        let sets = (0..<workingSets).map { index in
            WorkoutSetModel(
                id: "\(id)-set-\(index)",
                authorId: "author-1",
                index: index + 1,
                reps: 8,
                weightKg: 80,
                isWarmup: false,
                completedAt: when,
                dateCreated: when
            )
        }
        return WorkoutSessionModel(
            id: id,
            authorId: "author-1",
            name: isRestDay ? "Rest" : "Push Day",
            dateCreated: when,
            endedAt: ended ? when : nil,
            exercises: sets.isEmpty ? [] : [
                WorkoutExerciseModel(
                    id: "we-\(id)",
                    authorId: "author-1",
                    templateId: "bench",
                    name: "Bench Press",
                    trackingMode: .weightReps,
                    index: 1,
                    sets: sets
                )
            ],
            isRestDay: isRestDay
        )
    }

    // MARK: - Weight trend

    /// The card reads the weigh-ins the user has logged. It used to read a property nothing ever
    /// filled, so the Weight Trend card said "No Entries" and drew a flat line however often they
    /// stood on the scale.
    @Test("Test The Weight Trend Card Reads Logged Weigh Ins")
    func testTheWeightTrendCardReadsLoggedWeighIns() {
        let screen = makeScreen(measurements: [weighIn(kilograms: 82, day: 4), weighIn(kilograms: 81.5, day: 6)])

        #expect(screen.presenter.weightTrendSparklineData.count == 2)
        #expect(screen.presenter.weightTrendSubtitle == "Last 7 Days")
        #expect(screen.presenter.weightTrendLatestValueText != Format.placeholder)
    }

    /// With nothing logged the card says so rather than printing a zero-kilogram bodyweight.
    @Test("Test With No Weigh Ins The Card Says So")
    func testWithNoWeighInsTheCardSaysSo() {
        let screen = makeScreen()

        #expect(screen.presenter.weightTrendSparklineData.isEmpty)
        #expect(screen.presenter.weightTrendSubtitle == "No Entries")
        #expect(screen.presenter.weightTrendLatestValueText == Format.placeholder)
    }

    /// Deleted weigh-ins leave the trend, and an entry that recorded no weight was never in it.
    @Test("Test Deleted And Weightless Entries Are Left Out")
    func testDeletedAndWeightlessEntriesAreLeftOut() {
        let screen = makeScreen(measurements: [
            weighIn(kilograms: 82, day: 4),
            weighIn(kilograms: 99, day: 6, deleted: true),
            BodyMeasurementEntry(authorId: "author-1", waistCircumference: 80, date: date(day: 7))
        ])

        #expect(screen.presenter.weightTrendSparklineData.count == 1)
    }

    /// The smoothing runs in kilograms and only the display converts, so a pounds user sees the
    /// same curve in their own unit rather than a differently-smoothed one.
    @Test("Test The Trend Is Shown In The Users Unit")
    func testTheTrendIsShownInTheUsersUnit() {
        let metric = makeScreen(measurements: [weighIn(kilograms: 100, day: 4)])
        let imperial = makeScreen(measurements: [weighIn(kilograms: 100, day: 4)], weightUnit: .pounds)

        #expect(metric.presenter.weightTrendLatestValueText == "100.0")
        #expect(metric.presenter.weightTrendUnitText == "kg")
        #expect(imperial.presenter.weightTrendLatestValueText == "220.5")
        #expect(imperial.presenter.weightTrendUnitText == "lb")
    }

    /// The card is the last seven weigh-ins, taken after sorting, so an eighth older reading drops
    /// off rather than displacing the newest.
    @Test("Test The Card Keeps The Last Seven Weigh Ins")
    func testTheCardKeepsTheLastSevenWeighIns() {
        let screen = makeScreen(measurements: (1...9).map { weighIn(kilograms: Double(80 + $0), day: $0) })

        #expect(screen.presenter.weightTrendSparklineData.count == 7)
        #expect(screen.presenter.weightTrendSparklineData.last?.date == date(day: 9))
    }

    // MARK: - Goal progress

    /// With no goal the card offers to set one instead of claiming 0% of nothing.
    @Test("Test With No Goal The Card Says So")
    func testWithNoGoalTheCardSaysSo() {
        let screen = makeScreen(measurements: [weighIn(kilograms: 82, day: 4)])

        #expect(screen.presenter.hasActiveGoal == false)
        #expect(screen.presenter.goalProgressSubtitle == "No Goal Set")
        #expect(screen.presenter.goalProgressLatestValueText == Format.placeholder)
    }

    /// Progress is measured from the weigh-ins logged since the goal was set. A weight from before
    /// it would count the user's history against a target they had not chosen yet.
    @Test("Test Only Weigh Ins Since The Goal Count")
    func testOnlyWeighInsSinceTheGoalCount() {
        let goal = WeightGoal(
            userId: "user-1",
            objective: .loseWeight,
            startingWeightKg: 90,
            targetWeightKg: 80,
            weeklyChangeKg: 0.5,
            createdAt: date(day: 5)
        )
        let screen = makeScreen(measurements: [weighIn(kilograms: 85, day: 2)], goal: goal)

        #expect(screen.presenter.hasActiveGoal)
        #expect(screen.presenter.goalProgressSubtitle == "No Entries")
        #expect(screen.presenter.goalProgressLatestValueText == Format.placeholder)
    }

    @Test("Test Progress Is Measured From The Latest Weigh In")
    func testProgressIsMeasuredFromTheLatestWeighIn() {
        let goal = WeightGoal(
            userId: "user-1",
            objective: .loseWeight,
            startingWeightKg: 90,
            targetWeightKg: 80,
            weeklyChangeKg: 0.5,
            createdAt: date(day: 1)
        )
        let screen = makeScreen(measurements: [weighIn(kilograms: 88, day: 2), weighIn(kilograms: 85, day: 6)], goal: goal)

        #expect(screen.presenter.goalProgressPercent == 50)
        #expect(screen.presenter.goalProgressLatestValueText == "50")
        #expect(screen.presenter.goalProgressUnitText == "%")
    }

    /// The card draws progress as a bar, so a goal overshot has to read as full rather than
    /// sending the bar past its own end.
    @Test("Test An Overshot Goal Reads As Complete")
    func testAnOvershotGoalReadsAsComplete() {
        let goal = WeightGoal(
            userId: "user-1",
            objective: .loseWeight,
            startingWeightKg: 90,
            targetWeightKg: 80,
            weeklyChangeKg: 0.5,
            createdAt: date(day: 1)
        )
        let screen = makeScreen(measurements: [weighIn(kilograms: 72, day: 6)], goal: goal)

        #expect(screen.presenter.goalProgressPercent == 100)
    }

    /// Moving away from the target is no progress, not negative progress.
    @Test("Test Moving The Wrong Way Reads As No Progress")
    func testMovingTheWrongWayReadsAsNoProgress() {
        let goal = WeightGoal(
            userId: "user-1",
            objective: .loseWeight,
            startingWeightKg: 90,
            targetWeightKg: 80,
            weeklyChangeKg: 0.5,
            createdAt: date(day: 1)
        )
        let screen = makeScreen(measurements: [weighIn(kilograms: 94, day: 6)], goal: goal)

        #expect(screen.presenter.goalProgressPercent == 0)
    }

    // MARK: - Workouts

    /// Rest days are written ahead of time by the training program, already marked ended and dated
    /// into the future. Counted as workouts they fill the "Last 7 Workouts" card with sessions that
    /// have not happened and no sets in them.
    @Test("Test A Rest Day Is Not One Of The Last Seven Workouts")
    func testARestDayIsNotOneOfTheLastSevenWorkouts() async {
        let screen = makeScreen(sessions: [
            session(id: "real", day: 4, workingSets: 5),
            session(id: "rest", day: 28, workingSets: 0, isRestDay: true)
        ])

        #expect(screen.presenter.workoutLast7Sessions.map(\.id) == ["real"])
        #expect(screen.presenter.workoutLatestValueText == "5")
    }

    /// A workout still being logged is not a finished one.
    @Test("Test A Workout In Progress Is Not Counted")
    func testAWorkoutInProgressIsNotCounted() {
        let screen = makeScreen(sessions: [
            session(id: "done", day: 4, workingSets: 5),
            session(id: "live", day: 5, workingSets: 9, ended: false)
        ])

        #expect(screen.presenter.workoutLast7Sessions.map(\.id) == ["done"])
    }

    /// The card is the seven most recent workouts, drawn oldest to newest so the sparkline reads
    /// left to right.
    @Test("Test The Card Is The Seven Most Recent Workouts Oldest First")
    func testTheCardIsTheSevenMostRecentWorkoutsOldestFirst() {
        let screen = makeScreen(sessions: (1...9).map { session(id: "s\($0)", day: $0, workingSets: 1) })

        let sessions = screen.presenter.workoutLast7Sessions
        #expect(sessions.count == 7)
        #expect(sessions.first?.id == "s3")
        #expect(sessions.last?.id == "s9")
        #expect(screen.presenter.workoutSparklineData.map(\.date) == sessions.map { $0.endedAt ?? $0.dateCreated })
    }

    /// The headline is the total working sets across those workouts.
    @Test("Test The Workout Figure Totals The Sets")
    func testTheWorkoutFigureTotalsTheSets() {
        let screen = makeScreen(sessions: [
            session(id: "a", day: 4, workingSets: 12),
            session(id: "b", day: 6, workingSets: 8)
        ])

        #expect(screen.presenter.workoutLatestValueText == "20")
        #expect(screen.presenter.workoutUnitText == "sets")
    }

    @Test("Test With No Workouts The Card Says So")
    func testWithNoWorkoutsTheCardSaysSo() {
        let screen = makeScreen()

        #expect(screen.presenter.workoutSubtitle == "No Workouts")
        #expect(screen.presenter.workoutLatestValueText == Format.placeholder)
    }

    // MARK: - Energy balance and expenditure

    /// The intake line covers the seven days ending today, one point per day.
    @Test("Test Intake Covers The Week Ending Today")
    func testIntakeCoversTheWeekEndingToday() async {
        let screen = makeScreen(logged: [6: 1800, 0: 2200])

        await screen.presenter.onFirstTask()

        #expect(screen.presenter.energyBalanceIntake.data.count == 7)
        #expect(screen.presenter.energyBalanceIntake.data.first?.value == 1800)
        #expect(screen.presenter.energyBalanceIntake.data.last?.value == 2200)
    }

    /// The deficit is the week's average intake against expenditure, and it is only stated once a
    /// full week has been read.
    @Test("Test The Deficit Compares A Weeks Average With Expenditure")
    func testTheDeficitComparesAWeeksAverageWithExpenditure() async {
        let screen = makeScreen(logged: [0: 7000], tdee: 3000)

        await screen.presenter.onFirstTask()

        // 7,000 kcal over seven days averages 1,000 against a 3,000 expenditure.
        #expect(screen.presenter.energyBalanceLatestValueText == "\(2000.formatted()) deficit")
        #expect(screen.presenter.energyBalanceUnitText == "kcal")
    }

    @Test("Test Eating Over Expenditure Reads As A Surplus")
    func testEatingOverExpenditureReadsAsASurplus() async {
        let screen = makeScreen(logged: [0: 28_000], tdee: 3000)

        await screen.presenter.onFirstTask()

        #expect(screen.presenter.energyBalanceLatestValueText == "\(1000.formatted()) surplus")
    }

    /// Before the week has been read there is no average to state.
    @Test("Test Before Loading There Is No Balance To State")
    func testBeforeLoadingThereIsNoBalanceToState() {
        let screen = makeScreen(logged: [0: 2000])

        #expect(screen.presenter.energyBalanceLatestValueText == Format.placeholder)
    }

    /// Expenditure is a flat line at the estimate, one point per day of the week.
    @Test("Test Expenditure Is A Flat Week At The Estimate")
    func testExpenditureIsAFlatWeekAtTheEstimate() {
        let screen = makeScreen(tdee: 2750)

        #expect(screen.presenter.expenditureSparklineData.count == 7)
        #expect(screen.presenter.expenditureSparklineData.allSatisfy { $0.value == 2750 })
        #expect(screen.presenter.expenditureLatestValueText == 2750.formatted())
    }

    /// Without enough profile to estimate an expenditure the card says nothing rather than zero
    /// calories a day.
    @Test("Test With No Estimate The Expenditure Card Says So")
    func testWithNoEstimateTheExpenditureCardSaysSo() {
        let screen = makeScreen(tdee: 0)

        #expect(screen.presenter.expenditureLatestValueText == Format.placeholder)
    }

    // MARK: - Navigation

    @Test("Test Each Card Opens Its Own Screen")
    func testEachCardOpensItsOwnScreen() {
        let screen = makeScreen()

        screen.presenter.onWeightTrendPressed(themeColor: nil)
        screen.presenter.onGoalProgressPressed(themeColor: nil)
        screen.presenter.onEnergyBalancePressed(themeColor: nil)
        screen.presenter.onWorkoutsPressed(themeColor: nil)
        screen.presenter.onExpenditurePressed(themeColor: nil)

        #expect(screen.router.shown == ["weightTrend", "goalProgress", "energyBalance", "workouts", "expenditure"])
    }

    @Test("Test Appearing Is Tracked")
    func testAppearingIsTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["InsightsAndAnalyticsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["InsightsAndAnalyticsView_Disappear"])
    }
}
