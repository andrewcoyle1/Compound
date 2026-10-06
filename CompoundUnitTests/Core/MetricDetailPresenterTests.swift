//
//  MetricDetailPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The Goal Progress screen.
///
/// Progress is measured from the weight the goal was set at, so weigh-ins from before it started
/// are not part of it — including them would credit the user with progress they made towards a
/// different target, or none at all.
@MainActor
struct GoalProgressPresenterTests {

    private final class Interactor: SpyGlobalInteractor, GoalProgressInteractor {
        var currentUser: UserModel?
        var currentGoal: WeightGoal?
        var bodyMeasurements: [BodyMeasurementEntry] = []
    }

    private final class Router: GoalProgressRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var didShowLogWeight = false
        private(set) var didShowWeightGoalFlow = false

        func showWeightGoalFlow(editing: WeightGoal?) { didShowWeightGoalFlow = true }

        func showLogWeightView() {
            didShowLogWeight = true
        }
    }

    private struct Screen {
        let presenter: GoalProgressPresenter
        let interactor: Interactor
        let router: Router
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func goal(from: Double, target: Double, startedDaysAgo: Int = 30) -> WeightGoal {
        WeightGoal(
            userId: "user-1",
            objective: target < from ? .loseWeight : .gainWeight,
            startingWeightKg: from,
            targetWeightKg: target,
            weeklyChangeKg: 0.5,
            createdAt: start.addingTimeInterval(Double(-startedDaysAgo) * 86400)
        )
    }

    private func weighIn(id: String, weight: Double, daysAgo: Int, deleted: Bool = false) -> BodyMeasurementEntry {
        let date = start.addingTimeInterval(Double(-daysAgo) * 86400)
        return BodyMeasurementEntry(
            id: id,
            authorId: "author-1",
            weightKg: weight,
            date: date,
            source: .manual,
            dateCreated: date,
            deletedAt: deleted ? date : nil
        )
    }

    private func makeScreen(goal: WeightGoal?, weighIns: [BodyMeasurementEntry] = [], unit: WeightUnitPreference? = nil) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = unit.map { UserModel(userId: "user-1", submittedWeightUnitPreference: $0) }
        interactor.currentGoal = goal
        interactor.bodyMeasurements = weighIns
        let router = Router()
        return Screen(
            presenter: GoalProgressPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - No goal

    /// Without a goal there is nothing to measure against, so the screen shows its empty state
    /// rather than a chart of nothing.
    @Test("Test No Goal Leaves The Screen Empty")
    func testNoGoalLeavesTheScreenEmpty() async {
        let screen = makeScreen(goal: nil, weighIns: [weighIn(id: "w1", weight: 80, daysAgo: 1)])

        await screen.presenter.onAppear()

        #expect(screen.presenter.activeGoal == nil)
        #expect(screen.presenter.entries.isEmpty)
        #expect(screen.presenter.timeSeries.isEmpty)
        #expect(screen.presenter.currentWeightKg == nil)
    }

    // MARK: - Progress

    /// Halfway from 80 kg to 70 kg is 50%.
    @Test("Test Progress Is Measured From The Goal's Starting Weight")
    func testProgressIsMeasuredFromTheGoalsStartingWeight() async throws {
        let screen = makeScreen(
            goal: goal(from: 80, target: 70),
            weighIns: [weighIn(id: "w1", weight: 75, daysAgo: 1)]
        )

        await screen.presenter.onAppear()

        let entry = try #require(screen.presenter.entries.first)
        #expect(entry.progressPercent == 50)
        #expect(screen.presenter.currentWeightKg == 75)
    }

    @Test("Test Reaching The Target Is Full Progress")
    func testReachingTheTargetIsFullProgress() async throws {
        let screen = makeScreen(
            goal: goal(from: 80, target: 70),
            weighIns: [weighIn(id: "w1", weight: 70, daysAgo: 1)]
        )

        await screen.presenter.onAppear()

        #expect(try #require(screen.presenter.entries.first).progressPercent == 100)
    }

    /// Moving the wrong way is not negative progress, it is none — the chart floors at zero rather
    /// than showing a user below the axis.
    @Test("Test Moving The Wrong Way Is No Progress")
    func testMovingTheWrongWayIsNoProgress() async throws {
        let screen = makeScreen(
            goal: goal(from: 80, target: 70),
            weighIns: [weighIn(id: "w1", weight: 82, daysAgo: 1)]
        )

        await screen.presenter.onAppear()

        #expect(try #require(screen.presenter.entries.first).progressPercent == 0)
    }

    // MARK: - Which weigh-ins count

    /// The key rule: a weigh-in from before the goal started is not progress towards it.
    @Test("Test Weigh-Ins From Before The Goal Are Left Out")
    func testWeighInsFromBeforeTheGoalAreLeftOut() async {
        let screen = makeScreen(
            goal: goal(from: 80, target: 70, startedDaysAgo: 10),
            weighIns: [
                weighIn(id: "before", weight: 85, daysAgo: 20),
                weighIn(id: "after", weight: 78, daysAgo: 5)
            ]
        )

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.map(\.id) == ["after"])
    }

    @Test("Test Deleted And Weightless Entries Are Left Out")
    func testDeletedAndWeightlessEntriesAreLeftOut() async {
        let screen = makeScreen(
            goal: goal(from: 80, target: 70),
            weighIns: [
                weighIn(id: "gone", weight: 78, daysAgo: 5, deleted: true),
                weighIn(id: "kept", weight: 76, daysAgo: 3)
            ]
        )

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.map(\.id) == ["kept"])
    }

    @Test("Test Entries Run Oldest First And The Current Weight Is The Newest")
    func testEntriesRunOldestFirstAndTheCurrentWeightIsTheNewest() async {
        let screen = makeScreen(
            goal: goal(from: 80, target: 70),
            weighIns: [
                weighIn(id: "w2", weight: 76, daysAgo: 3),
                weighIn(id: "w1", weight: 78, daysAgo: 5),
                weighIn(id: "w3", weight: 74, daysAgo: 1)
            ]
        )

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.map(\.id) == ["w1", "w2", "w3"])
        #expect(screen.presenter.currentWeightKg == 74)
    }

    /// The screen reads the weigh-ins live rather than caching them on appear, which once had no
    /// reachable caller and left it empty however much history existed. A goal set from its empty
    /// state, or a weigh-in imported while it is open, shows without it appearing again.
    @Test("Test The Screen Shows History Without Waiting To Appear")
    func testTheScreenShowsHistoryWithoutWaitingToAppear() {
        let screen = makeScreen(
            goal: goal(from: 80, target: 70),
            weighIns: [weighIn(id: "w1", weight: 75, daysAgo: 1)]
        )

        #expect(screen.presenter.entries.count == 1)
    }

    @Test("Test Adding A Weight Opens The Logging Screen")
    func testAddingAWeightOpensTheLoggingScreen() {
        let screen = makeScreen(goal: goal(from: 80, target: 70))

        screen.presenter.onAddWeightPressed()

        #expect(screen.router.didShowLogWeight)
    }

    // MARK: - Units

    /// Goals and weigh-ins are stored in kilograms, but a pounds user reads pounds everywhere else,
    /// so this screen must not be the one place that shows kilograms.
    @Test("Test A Pounds User Sees Entries And Labels In Pounds")
    func testAPoundsUserSeesEntriesAndLabelsInPounds() async throws {
        let screen = makeScreen(
            goal: goal(from: 100, target: 90),
            weighIns: [weighIn(id: "w1", weight: 95, daysAgo: 1)],
            unit: .pounds
        )

        await screen.presenter.onAppear()
        let entry = try #require(screen.presenter.entries.first)

        #expect(screen.presenter.weightUnit == .pounds)
        #expect(entry.displayValue.hasPrefix(Format.weight(kg: 95, unit: WeightUnitPreference.pounds)))
        #expect(entry.displayValue.contains("lb"))
        #expect(screen.presenter.weightText(90) == Format.weight(kg: 90, unit: WeightUnitPreference.pounds))
        // Progress is unit-free: halfway is halfway in either unit.
        #expect(abs(entry.progressPercent - 50) < 0.001)
    }

    @Test("Test A Kilogram Or Unknown User Sees Kilograms")
    func testAKilogramOrUnknownUserSeesKilograms() async throws {
        for unit in [WeightUnitPreference.kilograms, nil] {
            let screen = makeScreen(
                goal: goal(from: 100, target: 90),
                weighIns: [weighIn(id: "w1", weight: 95, daysAgo: 1)],
                unit: unit
            )

            await screen.presenter.onAppear()
            let entry = try #require(screen.presenter.entries.first)

            #expect(entry.displayValue.hasPrefix(Format.weight(kg: 95, unit: WeightUnitPreference.kilograms)))
            #expect(screen.presenter.weightText(90) == Format.weight(kg: 90, unit: WeightUnitPreference.kilograms))
        }
    }
}

/// The Expenditure screen, which plots the user's TDEE across the last ninety days.
///
/// Expenditure is an estimate rather than a measurement, so every day carries the same figure. The
/// point of the tests is the window: ninety days, ending today, however the estimate is derived.
@MainActor
struct ExpenditureDetailPresenterTests {

    private final class Interactor: SpyGlobalInteractor, ExpenditureDetailInteractor {
        var currentUser: UserModel?
        var tdee: Double = 2500
        var expenditureHistory: [ExpenditureEstimate] = []
        private(set) var estimateCallCount = 0

        func estimateTDEE(user: UserModel?) -> Double {
            estimateCallCount += 1
            return tdee
        }
    }

    private final class Router: ExpenditureDetailRouter {
        private(set) var coachContexts: [CoachContext] = []
        func showCoach(context: CoachContext) { coachContexts.append(context) }
        let router: AnyRouter = TestRouting.anyRouter

        func showEditProfileView(delegate: EditProfileDelegate) { }
    }

    private func makePresenter(tdee: Double = 2500) -> ExpenditureDetailPresenter {
        let interactor = Interactor()
        interactor.tdee = tdee
        return ExpenditureDetailPresenter(interactor: interactor, router: Router())
    }

    @Test("Test The Screen Covers Ninety Days")
    func testTheScreenCoversNinetyDays() async {
        let presenter = makePresenter()

        await presenter.onAppear()

        #expect(presenter.entries.count == 90)
        #expect(presenter.timeSeries.first?.data.count == 90)
    }

    @Test("Test Every Day Carries The Estimate")
    func testEveryDayCarriesTheEstimate() async {
        let presenter = makePresenter(tdee: 2750)

        await presenter.onAppear()

        #expect(presenter.entries.allSatisfy { $0.expenditure == 2750 })
    }

    /// The list reads newest first, as the other metric screens do, while the chart plots forwards
    /// in time.
    @Test("Test The List Reads Newest First And The Chart Oldest First")
    func testTheListReadsNewestFirstAndTheChartOldestFirst() async throws {
        let presenter = makePresenter()

        await presenter.onAppear()

        let listDates = presenter.entries.map(\.date)
        let chartDates = try #require(presenter.timeSeries.first).data.map(\.date)

        #expect(listDates == listDates.sorted(by: >))
        #expect(chartDates == chartDates.sorted())
    }

    @Test("Test The Window Ends Today")
    func testTheWindowEndsToday() async throws {
        let presenter = makePresenter()

        await presenter.onAppear()

        let newest = try #require(presenter.entries.first)
        #expect(Calendar.current.isDateInToday(newest.date))
    }

    @Test("Test Each Day Is Keyed By Its Own Date")
    func testEachDayIsKeyedByItsOwnDate() async {
        let presenter = makePresenter()

        await presenter.onAppear()

        #expect(Set(presenter.entries.map(\.id)).count == 90)
    }

    /// The flat line above is the fallback for an account that has logged nothing. Once there is
    /// an adaptive history the chart plots that instead, which is the whole point of the engine.
    @Test("Test The Chart Follows The Adaptive History Where There Is One")
    func testTheChartFollowsTheAdaptiveHistoryWhereThereIsOne() async throws {
        let interactor = Interactor()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        interactor.expenditureHistory = (0..<30).map { offset in
            ExpenditureEstimate(
                day: calendar.date(byAdding: .day, value: offset - 29, to: startOfToday) ?? startOfToday,
                kcal: 2400 + Double(offset),
                source: .adaptive,
                isProvisional: false,
                trendWeightKg: 80,
                weeklyTrendChangeKg: 0,
                loggedDays: 28,
                weighInCount: 20,
                windowDays: 28,
                stepAdjustmentKcal: 0
            )
        }
        let presenter = ExpenditureDetailPresenter(interactor: interactor, router: Router())

        await presenter.onAppear()

        #expect(presenter.entries.count == 30)
        #expect(presenter.entries.first?.expenditure == 2429)
        #expect(try #require(presenter.timeSeries.first).data.count == 30)
    }
}

/// The Steps screen.
///
/// Steps arrive from HealthKit, which can report the same day more than once as the count is
/// revised through the day. The screen keeps the largest reading per day, since steps only ever
/// accumulate — taking the newest would show a lower count if a later sample was partial.
@MainActor
struct StepsPresenterTests {

    private final class Interactor: SpyGlobalInteractor, StepsInteractor {
        var userId: String? = "author-1"
        var stepsHistory: [StepsModel] = []
        var canRequestAuthorisation = false
        private(set) var didBackfill = false
        private(set) var didRequestAuthorisation = false

        func syncStepsFromHealthKit(fromScratch: Bool) async {
            didBackfill = true
        }

        func canRequestHealthDataAuthorisation() -> Bool {
            canRequestAuthorisation
        }

        func requestHealthKitAuthorisation(for scope: HealthDataScope) async throws {
            didRequestAuthorisation = true
        }
    }

    private final class Router: StepsRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private struct Screen {
        let presenter: StepsPresenter
        let interactor: Interactor
    }

    private func steps(id: String, number: Int, daysAgo: Int, authorId: String = "author-1", deleted: Bool = false) -> StepsModel {
        let date = Calendar.current.startOfDay(for: .now)
            .addingTimeInterval(Double(-daysAgo) * 86400 + 12 * 3600)
        return StepsModel(
            id: id,
            authorId: authorId,
            number: number,
            date: date,
            deletedAt: deleted ? date : nil
        )
    }

    private func makeScreen(_ history: [StepsModel], canRequest: Bool = false) -> Screen {
        let interactor = Interactor()
        interactor.stepsHistory = history
        interactor.canRequestAuthorisation = canRequest
        return Screen(
            presenter: StepsPresenter(interactor: interactor, router: Router()),
            interactor: interactor
        )
    }

    // MARK: - Consolidating a day

    /// HealthKit revises a day's count as it goes, so the same day can arrive several times. Steps
    /// only accumulate, so the largest reading is the right one.
    @Test("Test A Day Keeps Its Largest Reading")
    func testADayKeepsItsLargestReading() async {
        let screen = makeScreen([
            steps(id: "morning", number: 2000, daysAgo: 1),
            steps(id: "evening", number: 8214, daysAgo: 1),
            steps(id: "midday", number: 5000, daysAgo: 1)
        ])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.count == 1)
        #expect(screen.presenter.entries.first?.steps == 8214)
    }

    @Test("Test Separate Days Stay Separate")
    func testSeparateDaysStaySeparate() async {
        let screen = makeScreen([
            steps(id: "d1", number: 8000, daysAgo: 2),
            steps(id: "d2", number: 9000, daysAgo: 1),
            steps(id: "d3", number: 10000, daysAgo: 0)
        ])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.count == 3)
    }

    // MARK: - What is left out

    @Test("Test Deleted Readings Are Left Out")
    func testDeletedReadingsAreLeftOut() async {
        let screen = makeScreen([
            steps(id: "gone", number: 99999, daysAgo: 1, deleted: true),
            steps(id: "kept", number: 8000, daysAgo: 1)
        ])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.first?.steps == 8000)
    }

    /// Another account's steps must never appear on this one's chart.
    @Test("Test Another Author's Readings Are Left Out")
    func testAnotherAuthorsReadingsAreLeftOut() async {
        let screen = makeScreen([
            steps(id: "mine", number: 8000, daysAgo: 1),
            steps(id: "theirs", number: 20000, daysAgo: 1, authorId: "someone-else")
        ])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.count == 1)
        #expect(screen.presenter.entries.first?.steps == 8000)
    }

    /// A steps sample keeps the time it was recorded at, and the window used to end at midnight —
    /// so a reading taken at any point during today was compared against the start of today and
    /// dropped. The screen was always a day behind.
    @Test("Test Today's Steps Are Included")
    func testTodaysStepsAreIncluded() async {
        let screen = makeScreen([steps(id: "today", number: 8214, daysAgo: 0)])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.map(\.id) == ["today"])
    }

    @Test("Test Tomorrow's Readings Are Left Out")
    func testTomorrowsReadingsAreLeftOut() async {
        let screen = makeScreen([steps(id: "tomorrow", number: 500, daysAgo: -1)])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.isEmpty)
    }

    @Test("Test Readings Older Than Ninety Days Are Left Out")
    func testReadingsOlderThanNinetyDaysAreLeftOut() async {
        let screen = makeScreen([
            steps(id: "old", number: 8000, daysAgo: 200),
            steps(id: "recent", number: 9000, daysAgo: 5)
        ])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.map(\.id) == ["recent"])
    }

    @Test("Test No Readings Leave The Screen Empty")
    func testNoReadingsLeaveTheScreenEmpty() async {
        let screen = makeScreen([])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.isEmpty)
        #expect(screen.presenter.timeSeries.first?.data.isEmpty == true)
    }

    // MARK: - Order

    @Test("Test The List Reads Newest First And The Chart Oldest First")
    func testTheListReadsNewestFirstAndTheChartOldestFirst() async throws {
        let screen = makeScreen([
            steps(id: "d1", number: 8000, daysAgo: 3),
            steps(id: "d2", number: 9000, daysAgo: 2),
            steps(id: "d3", number: 10000, daysAgo: 1)
        ])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.map(\.id) == ["d3", "d2", "d1"])
        let chartDates = try #require(screen.presenter.timeSeries.first).data.map(\.date)
        #expect(chartDates == chartDates.sorted())
    }

    // MARK: - HealthKit

    @Test("Test Appearing Asks Health For Newer Steps")
    func testAppearingAsksHealthForNewerSteps() async {
        let screen = makeScreen([])

        await screen.presenter.onAppear()

        #expect(screen.interactor.didBackfill)
    }

    @Test("Test Authorisation Is Requested Only When It Can Be")
    func testAuthorisationIsRequestedOnlyWhenItCanBe() async {
        let asks = makeScreen([], canRequest: true)
        let doesNot = makeScreen([], canRequest: false)

        await asks.presenter.onAppear()
        await doesNot.presenter.onAppear()

        #expect(asks.interactor.didRequestAuthorisation)
        #expect(!doesNot.interactor.didRequestAuthorisation)
    }

    /// A user who refuses Health access still gets the screen, showing whatever was logged before.
    @Test("Test Refused Authorisation Still Loads What Is There")
    func testRefusedAuthorisationStillLoadsWhatIsThere() async {
        let screen = makeScreen([steps(id: "d1", number: 8000, daysAgo: 1)], canRequest: true)

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.count == 1)
    }
}
