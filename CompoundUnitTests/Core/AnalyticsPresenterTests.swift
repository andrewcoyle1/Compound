//
//  AnalyticsPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The Analytics tab: a card per metric, each summarising the last week and opening a screen of its
/// own.
///
/// Every card has to say something when there is nothing to say, and the empty forms differ — "--"
/// for a missing number, "No Entries" or "No Workouts" for a missing series. A card that showed 0
/// instead would read as a measurement rather than an absence, which is the failure these tests are
/// mostly about.
///
/// The body-metrics figures are served from a cache keyed on a hash of the measurements, so the
/// weight, trend and body-fat cards do not re-sort the whole history on every read. That cache has
/// to notice an edit that leaves the count unchanged — clearing a weight, say — which is pinned
/// here.
@MainActor
struct AnalyticsPresenterTests {

    private struct Screen {
        let presenter: AnalyticsPresenter
        let interactor: AnalyticsInteractorDouble
        let router: AnalyticsRouterDouble
    }

    private let calendar = Calendar.current

    private func date(_ daysAgo: Int) -> Date {
        let midday = calendar.startOfDay(for: .now).addingTimeInterval(12 * 3600)
        return calendar.date(byAdding: .day, value: -daysAgo, to: midday) ?? midday
    }

    private func weighIn(
        id: String,
        daysAgo: Int,
        weightKg: Double? = 72,
        bodyFat: Double? = nil,
        deleted: Bool = false
    ) -> BodyMeasurementEntry {
        BodyMeasurementEntry(
            id: id,
            authorId: "author-1",
            weightKg: weightKg,
            bodyFatPercentage: bodyFat,
            date: date(daysAgo),
            source: .manual,
            dateCreated: date(daysAgo),
            deletedAt: deleted ? .now : nil
        )
    }

    private func session(id: String, daysAgo: Int, sets: Int = 1, warmups: Int = 0, ended: Bool = true) -> WorkoutSessionModel {
        let day = date(daysAgo)
        let working = (0..<sets).map { index in
            WorkoutSetModel(id: "\(id)-s\(index)", authorId: "author-1", index: index + 1, reps: 8, weightKg: 80, isWarmup: false, dateCreated: day)
        }
        let warm = (0..<warmups).map { index in
            WorkoutSetModel(
                id: "\(id)-w\(index)",
                authorId: "author-1",
                index: sets + index + 1,
                reps: 10,
                weightKg: 40,
                isWarmup: true,
                dateCreated: day
            )
        }
        return WorkoutSessionModel(
            id: id,
            authorId: "author-1",
            name: "Push Day",
            dateCreated: day,
            endedAt: ended ? day : nil,
            exercises: [
                WorkoutExerciseModel(
                    id: "\(id)-e1",
                    authorId: "author-1",
                    templateId: "template-1",
                    name: "Bench Press",
                    trackingMode: .weightReps,
                    index: 1,
                    sets: working + warm
                )
            ]
        )
    }

    private func steps(_ number: Int, daysAgo: Int, id: String? = nil) -> StepsModel {
        StepsModel(
            id: id ?? "steps-\(daysAgo)-\(number)",
            authorId: "author-1",
            number: number,
            date: date(daysAgo)
        )
    }

    private func makeScreen(
        weighIns: [BodyMeasurementEntry] = [],
        sessions: [WorkoutSessionModel] = [],
        stepsHistory: [StepsModel] = [],
        logged: [Int: Double] = [:],
        goal: WeightGoal? = nil,
        tdee: Double = 3000,
        hidden: [AnalyticsSection] = []
    ) -> Screen {
        let interactor = AnalyticsInteractorDouble()
        interactor.bodyMeasurements = weighIns
        interactor.workoutSessions = sessions
        interactor.stepsHistory = stepsHistory
        interactor.currentGoal = goal
        interactor.tdee = tdee
        interactor.analyticsSettings.hiddenSectionIds = hidden.map(\.rawValue)
        interactor.totalsByDay = Dictionary(uniqueKeysWithValues: logged.map { daysAgo, calories in
            (date(daysAgo).dayKey, DailyMacroTarget(calories: calories, proteinGrams: 150, carbGrams: 200, fatGrams: 70))
        })
        let router = AnalyticsRouterDouble()
        return Screen(
            presenter: AnalyticsPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - Empty states

    /// Nothing logged anywhere: every card should say so rather than show a zero.
    @Test("Test An Empty Tab Reads As Absent, Not Zero")
    func testAnEmptyTabReadsAsAbsentNotZero() {
        let screen = makeScreen()

        #expect(screen.presenter.scaleWeightLatestValueText == Format.placeholder)
        #expect(screen.presenter.scaleWeightSubtitle == "No Entries")
        #expect(screen.presenter.weightTrendLatestValueText == Format.placeholder)
        #expect(screen.presenter.bodyFatLatestValueText == Format.placeholder)
        #expect(screen.presenter.bodyFatSubtitle == "No Entries")
        #expect(screen.presenter.workoutLatestValueText == Format.placeholder)
        #expect(screen.presenter.workoutSubtitle == "No Workouts")
        #expect(screen.presenter.stepsLatestValueText == Format.placeholder)
        #expect(screen.presenter.stepsSubtitle == "No Data")
    }

    // MARK: - Weight

    @Test("Test The Weight Card Shows The Most Recent Entry")
    func testTheWeightCardShowsTheMostRecentEntry() {
        let screen = makeScreen(weighIns: [
            weighIn(id: "old", daysAgo: 5, weightKg: 75),
            weighIn(id: "new", daysAgo: 1, weightKg: 72)
        ])

        #expect(screen.presenter.scaleWeightSparklineData.map(\.value) == [75, 72])
        #expect(screen.presenter.scaleWeightLatestValueText.contains("72"))
        #expect(screen.presenter.scaleWeightSubtitle == "Last 7 Entries")
    }

    /// The card is the last seven weigh-ins, however far back they run.
    @Test("Test The Weight Card Keeps Only The Last Seven Entries")
    func testTheWeightCardKeepsOnlyTheLastSevenEntries() {
        let screen = makeScreen(weighIns: (0..<10).map { weighIn(id: "w\($0)", daysAgo: $0) })

        #expect(screen.presenter.scaleWeightSparklineData.count == 7)
    }

    /// An entry recording only a circumference is not a weigh-in, and a deleted one is not there at
    /// all.
    @Test("Test Entries Without A Weight And Deleted Ones Are Left Out")
    func testEntriesWithoutAWeightAndDeletedOnesAreLeftOut() {
        let screen = makeScreen(weighIns: [
            weighIn(id: "waist", daysAgo: 3, weightKg: nil),
            weighIn(id: "binned", daysAgo: 2, weightKg: 80, deleted: true),
            weighIn(id: "real", daysAgo: 1, weightKg: 72)
        ])

        #expect(screen.presenter.scaleWeightSparklineData.map(\.value) == [72])
    }

    /// The cached figures are keyed on a hash of the measurements. Clearing a weight leaves the
    /// count and the id unchanged, so a cache keyed only on count would go on showing the old
    /// number.
    @Test("Test Clearing A Weight Invalidates The Cache")
    func testClearingAWeightInvalidatesTheCache() {
        let screen = makeScreen(weighIns: [weighIn(id: "w1", daysAgo: 1, weightKg: 72)])
        #expect(screen.presenter.scaleWeightSparklineData.count == 1)

        screen.interactor.bodyMeasurements = [weighIn(id: "w1", daysAgo: 1, weightKg: nil)]

        #expect(screen.presenter.scaleWeightSparklineData.isEmpty)
    }

    @Test("Test Body Fat Is Its Own Series")
    func testBodyFatIsItsOwnSeries() {
        let screen = makeScreen(weighIns: [
            weighIn(id: "w1", daysAgo: 2, weightKg: 72, bodyFat: nil),
            weighIn(id: "w2", daysAgo: 1, weightKg: 72, bodyFat: 18.4)
        ])

        #expect(screen.presenter.bodyFatSparklineData.map(\.value) == [18.4])
        #expect(screen.presenter.bodyFatLatestValueText == "18.4")
        #expect(screen.presenter.bodyFatUnitText == "%")
    }

    // MARK: - Workouts

    @Test("Test The Workout Card Counts Working Sets Only")
    func testTheWorkoutCardCountsWorkingSetsOnly() {
        let screen = makeScreen(sessions: [session(id: "s1", daysAgo: 1, sets: 3, warmups: 2)])

        screen.presenter.loadWorkoutData()

        #expect(screen.presenter.workoutLatestValueText == "3")
        #expect(screen.presenter.workoutSparklineData.map(\.value) == [3])
        #expect(screen.presenter.workoutUnitText == "sets")
    }

    /// A workout still in progress is not history.
    @Test("Test Unfinished Workouts Are Left Out")
    func testUnfinishedWorkoutsAreLeftOut() {
        let screen = makeScreen(sessions: [
            session(id: "done", daysAgo: 1),
            session(id: "live", daysAgo: 0, ended: false)
        ])

        screen.presenter.loadWorkoutData()

        #expect(screen.presenter.workoutSparklineData.count == 1)
    }

    /// The card is the last seven workouts, and it reads forwards in time however they arrived.
    @Test("Test The Workout Card Keeps The Last Seven, Oldest First")
    func testTheWorkoutCardKeepsTheLastSevenOldestFirst() {
        let screen = makeScreen(sessions: (0..<10).map { session(id: "s\($0)", daysAgo: $0) })

        screen.presenter.loadWorkoutData()

        let dates = screen.presenter.workoutSparklineData.map(\.date)
        #expect(dates.count == 7)
        #expect(dates == dates.sorted())
    }

    @Test("Test The Contribution Grid Is Always Thirty Cells")
    func testTheContributionGridIsAlwaysThirtyCells() {
        let screen = makeScreen(sessions: [session(id: "s1", daysAgo: 0)])

        screen.presenter.loadWorkoutData()

        #expect(screen.presenter.workoutContributionData.count == 30)
        #expect(screen.presenter.workoutContributionData.last == 1.0)
    }

    // MARK: - Nutrition

    @Test("Test The Macros Card Averages The Week")
    func testTheMacrosCardAveragesTheWeek() {
        let screen = makeScreen(logged: [0: 2100, 1: 2100, 2: 2100, 3: 2100, 4: 2100, 5: 2100, 6: 2100])

        screen.presenter.loadMacrosData()

        #expect(screen.presenter.macrosAverageCalories == 2100)
    }

    /// Days with nothing logged are answered as zero, so an average over a part-logged week is
    /// dragged down — that is the figure the card shows, and pinning it keeps the card and the
    /// Energy Balance screen from disagreeing silently.
    @Test("Test A Part-Logged Week Averages Over All Seven Days")
    func testAPartLoggedWeekAveragesOverAllSevenDays() {
        let screen = makeScreen(logged: [0: 2100, 1: 2100])

        screen.presenter.loadMacrosData()

        #expect(screen.presenter.macrosAverageCalories == 600)
    }

    @Test("Test Nothing Logged Averages To Nothing")
    func testNothingLoggedAveragesToNothing() {
        let screen = makeScreen()

        #expect(screen.presenter.macrosAverageCalories == 0)
        #expect(screen.presenter.proteinCurrent == 0)
    }

    /// Without a target the protein ring still needs a ceiling to draw against, so it falls back to
    /// a sensible one rather than dividing by zero.
    @Test("Test The Protein Ring Has A Ceiling Without A Target")
    func testTheProteinRingHasACeilingWithoutATarget() {
        let screen = makeScreen()

        #expect(screen.presenter.proteinTarget == nil)
        #expect(screen.presenter.proteinMax == 180)
    }

    /// Eating past the target must not overflow the ring, so the ceiling rises to what was eaten.
    @Test("Test The Protein Ring Stretches Past The Target")
    func testTheProteinRingStretchesPastTheTarget() async {
        let screen = makeScreen(logged: [0: 2100])
        screen.interactor.target = DailyMacroTarget(calories: 2000, proteinGrams: 100, carbGrams: 200, fatGrams: 70)

        screen.presenter.loadMacrosData()
        await screen.presenter.loadDailyTarget()

        // 150 g logged against a 100 g target: the ring reaches what was eaten.
        #expect(screen.presenter.proteinCurrent == 150)
        #expect(screen.presenter.proteinMax == 150)
    }

    // MARK: - Energy balance

    @Test("Test Expenditure Is The Same Every Day")
    func testExpenditureIsTheSameEveryDay() {
        let screen = makeScreen(tdee: 2750)

        #expect(screen.presenter.expenditureSparklineData.allSatisfy { $0.value == 2750 })
        #expect(screen.presenter.expenditureLatestValueText == 2750.formatted())
        #expect(screen.presenter.expenditureUnitText == "kcal")
    }

    @Test("Test No Expenditure Reads As Absent")
    func testNoExpenditureReadsAsAbsent() {
        let screen = makeScreen(tdee: 0)

        #expect(screen.presenter.expenditureLatestValueText == Format.placeholder)
    }

    /// A deficit and a surplus have to read differently, and eating exactly the expenditure is
    /// neither.
    @Test("Test The Balance Reads As Deficit, Surplus Or Balanced")
    func testTheBalanceReadsAsDeficitSurplusOrBalanced() {
        let week = Dictionary(uniqueKeysWithValues: (0..<7).map { ($0, 2000.0) })
        let deficit = makeScreen(logged: week, tdee: 3000)
        let surplus = makeScreen(logged: week, tdee: 1500)
        let balanced = makeScreen(logged: week, tdee: 2000)

        deficit.presenter.loadMacrosData()
        surplus.presenter.loadMacrosData()
        balanced.presenter.loadMacrosData()

        #expect(deficit.presenter.energyBalanceLatestValueText == "\(1000.formatted()) kcal deficit")
        #expect(surplus.presenter.energyBalanceLatestValueText == "500 kcal surplus")
        #expect(balanced.presenter.energyBalanceLatestValueText == "Balanced")
    }

    /// The figure is an average over a full week, so it is not shown until there is one.
    @Test("Test The Balance Needs A Full Week")
    func testTheBalanceNeedsAFullWeek() {
        let screen = makeScreen(logged: [0: 2100])

        #expect(screen.presenter.energyBalanceLatestValueText == Format.placeholder)
    }

    // MARK: - Steps

    @Test("Test The Steps Card Shows The Last Seven Days")
    func testTheStepsCardShowsTheLastSevenDays() async {
        let screen = makeScreen(stepsHistory: (0..<3).map { steps(8000 + $0, daysAgo: $0) })

        await screen.presenter.loadStepsData()

        #expect(screen.presenter.stepsLast7.count == 3)
        #expect(screen.presenter.stepsSubtitle == "Last 7 Days")
        #expect(screen.presenter.stepsUnitText == "steps")
        #expect(screen.interactor.didBackfillSteps)
    }

    /// HealthKit and a manual entry can both report a day. The higher figure wins, so the card
    /// never shows a partial day's count next to a complete one.
    @Test("Test Two Readings For One Day Keep The Higher")
    func testTwoReadingsForOneDayKeepTheHigher() async {
        let screen = makeScreen(stepsHistory: [
            steps(4000, daysAgo: 1, id: "partial"),
            steps(9000, daysAgo: 1, id: "complete")
        ])

        await screen.presenter.loadStepsData()

        #expect(screen.presenter.stepsLast7.map(\.number) == [9000])
    }

    /// A reading is dated when it was taken, so a window ending at the *start* of today kept only a
    /// reading timed exactly at midnight — and today's steps, the one figure a user checks, never
    /// appeared.
    @Test("Test Today's Steps Are Shown")
    func testTodaysStepsAreShown() async {
        let screen = makeScreen(stepsHistory: [steps(9000, daysAgo: 0)])

        await screen.presenter.loadStepsData()

        #expect(screen.presenter.stepsLast7.map(\.number) == [9000])
        #expect(screen.presenter.stepsLatestValueText == 9000.formatted())
    }

    @Test("Test Steps Older Than A Week Are Left Out")
    func testStepsOlderThanAWeekAreLeftOut() async {
        let screen = makeScreen(stepsHistory: [steps(8000, daysAgo: 30), steps(9000, daysAgo: 1)])

        await screen.presenter.loadStepsData()

        #expect(screen.presenter.stepsLast7.map(\.number) == [9000])
    }

    // MARK: - Goal progress

    @Test("Test Without A Goal There Is No Progress To Show")
    func testWithoutAGoalThereIsNoProgressToShow() {
        let screen = makeScreen()

        #expect(!screen.presenter.hasActiveGoal)
        #expect(screen.presenter.goalProgressSubtitle == "No Goal Set")
        #expect(screen.presenter.goalProgressLatestValueText == Format.placeholder)
    }

    @Test("Test A Goal With No Weigh-Ins Since It Was Set Shows Nothing")
    func testAGoalWithNoWeighInsSinceItWasSetShowsNothing() {
        let goal = WeightGoal(
            userId: "author-1",
            objective: .loseWeight,
            startingWeightKg: 80,
            targetWeightKg: 70,
            weeklyChangeKg: -0.5,
            createdAt: date(1)
        )
        // The only weigh-in predates the goal.
        let screen = makeScreen(weighIns: [weighIn(id: "w1", daysAgo: 5, weightKg: 80)], goal: goal)

        #expect(screen.presenter.hasActiveGoal)
        #expect(screen.presenter.goalProgressSubtitle == "No Entries")
        #expect(screen.presenter.goalProgressLatestValueText == Format.placeholder)
    }

    @Test("Test Halfway To The Target Is Half The Bar")
    func testHalfwayToTheTargetIsHalfTheBar() {
        let goal = WeightGoal(
            userId: "author-1",
            objective: .loseWeight,
            startingWeightKg: 80,
            targetWeightKg: 70,
            weeklyChangeKg: -0.5,
            createdAt: date(10)
        )
        let screen = makeScreen(weighIns: [weighIn(id: "w1", daysAgo: 1, weightKg: 75)], goal: goal)

        #expect(screen.presenter.goalProgressPercent == 50)
        #expect(screen.presenter.goalProgressLatestValueText == "50")
        #expect(screen.presenter.goalProgressSubtitle == "Toward Target")
    }

    /// The card draws progress as a bar, so overshooting the target fills it rather than sending it
    /// off the end, and moving the wrong way empties it rather than going negative.
    @Test("Test Progress Is Clamped To The Bar")
    func testProgressIsClampedToTheBar() {
        let goal = WeightGoal(
            userId: "author-1",
            objective: .loseWeight,
            startingWeightKg: 80,
            targetWeightKg: 70,
            weeklyChangeKg: -0.5,
            createdAt: date(10)
        )
        let overshot = makeScreen(weighIns: [weighIn(id: "w1", daysAgo: 1, weightKg: 65)], goal: goal)
        let backwards = makeScreen(weighIns: [weighIn(id: "w1", daysAgo: 1, weightKg: 85)], goal: goal)

        #expect(overshot.presenter.goalProgressPercent == 100)
        #expect(backwards.presenter.goalProgressPercent == 0)
    }

    // MARK: - Customising the tab

    @Test("Test Every Section Is Visible By Default")
    func testEverySectionIsVisibleByDefault() {
        let screen = makeScreen()

        #expect(AnalyticsSection.allCases.allSatisfy { screen.presenter.isVisible($0) })
        #expect(screen.presenter.hiddenSections.isEmpty)
    }

    /// A hidden section has to stay reachable, so it moves to the More list rather than disappearing
    /// from the app.
    @Test("Test A Hidden Section Moves To The More List")
    func testAHiddenSectionMovesToTheMoreList() {
        let screen = makeScreen(hidden: [.habits])

        #expect(!screen.presenter.isVisible(.habits))
        #expect(screen.presenter.hiddenSections == [.habits])
    }

    /// The settings document is read live rather than snapshotted, so hiding a section on the
    /// Customise screen updates the tab behind it.
    @Test("Test Hiding A Section Takes Effect Immediately")
    func testHidingASectionTakesEffectImmediately() {
        let screen = makeScreen()

        screen.interactor.analyticsSettings.hiddenSectionIds = [AnalyticsSection.nutrition.rawValue]

        #expect(!screen.presenter.isVisible(.nutrition))
    }

    @Test("Test The More List Keeps The Tab's Own Order")
    func testTheMoreListKeepsTheTabsOwnOrder() {
        let screen = makeScreen(hidden: [.exercises, .habits])

        #expect(screen.presenter.hiddenSections == [.habits, .exercises])
    }

    /// A hidden section's row opens the same screen its "See All" would have.
    @Test("Test A Hidden Section Opens Its Own Screen")
    func testAHiddenSectionOpensItsOwnScreen() {
        let screen = makeScreen()

        for section in AnalyticsSection.allCases {
            screen.presenter.onHiddenSectionPressed(section)
        }

        #expect(screen.router.shown == [
            "insightsAndAnalytics", "habits", "nutrition", "bodyMetrics", "muscleGroups", "exercises"
        ])
    }

    // MARK: - Navigation

    @Test("Test Each Card Opens Its Own Screen")
    func testEachCardOpensItsOwnScreen() {
        let screen = makeScreen()

        screen.presenter.onScaleWeightPressed(themeColor: nil)
        screen.presenter.onWeightTrendPressed(themeColor: nil)
        screen.presenter.onGoalProgressPressed(themeColor: nil)
        screen.presenter.onEnergyBalancePressed(themeColor: nil)
        screen.presenter.onWorkoutsPressed(themeColor: nil)
        screen.presenter.onExpenditurePressed(themeColor: nil)
        screen.presenter.onStepsPressed(themeColor: nil)

        #expect(screen.router.shown == [
            "scaleWeight", "weightTrend", "goalProgress", "energyBalance", "workout", "expenditure", "steps"
        ])
    }

    @Test("Test Customising The Tab Opens Its Screen")
    func testCustomisingTheTabOpensItsScreen() {
        let screen = makeScreen()

        screen.presenter.onCustomiseAnalyticsPressed()

        #expect(screen.router.shown == ["customiseAnalytics"])
    }

    // MARK: - Analytics

    @Test("Test Appearing And Leaving Are Both Tracked")
    func testAppearingAndLeavingAreBothTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: AnalyticsDelegate())
        screen.presenter.onViewDisappear(delegate: AnalyticsDelegate())

        #expect(screen.interactor.trackedScreenEventNames == ["AnalyticsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["AnalyticsView_Disappear"])
    }
}

// MARK: - Muscle groups

extension AnalyticsPresenterTests {

    private func trainedSession(id: String, daysAgo: Int, templateId: String, sets: Int) -> WorkoutSessionModel {
        let day = date(daysAgo)
        let completed = (0..<sets).map { index in
            WorkoutSetModel(id: "\(id)-s\(index)", authorId: "author-1", index: index + 1, reps: 8, weightKg: 80, isWarmup: false, completedAt: day, dateCreated: day)
        }
        return WorkoutSessionModel(
            id: id,
            authorId: "author-1",
            name: "Workout",
            dateCreated: day,
            endedAt: day,
            exercises: [
                WorkoutExerciseModel(
                    id: "\(id)-e1",
                    authorId: "author-1",
                    templateId: templateId,
                    name: templateId,
                    trackingMode: .weightReps,
                    index: 1,
                    sets: completed
                )
            ]
        )
    }

    private func template(_ id: String, muscle: Muscles) -> ExerciseModel {
        ExerciseModel(
            id: id,
            authorId: "author-1",
            name: id,
            trackableMetrics: [.weight, .reps],
            type: .compoundUpper,
            laterality: .bilateral,
            muscleGroups: [muscle: .primary],
            isBodyweight: false,
            rangeOfMotion: 1,
            stability: 1,
            bodyWeightContribution: 0,
            alternateNames: []
        )
    }

    /// The cards say "Last 7 Days", so a muscle trained heavily a month ago neither counts toward
    /// them nor outranks one trained this week. They used to show and rank by every set ever logged.
    @Test("Test Muscle Cards Count And Rank Only The Last Seven Days")
    func testMuscleCardsCountOnlyTheLastSevenDays() {
        let screen = makeScreen(sessions: [
            trainedSession(id: "old-chest", daysAgo: 30, templateId: "bench", sets: 10),
            trainedSession(id: "chest", daysAgo: 2, templateId: "bench", sets: 1),
            trainedSession(id: "back", daysAgo: 1, templateId: "row", sets: 3)
        ])
        screen.interactor.allExercises = [template("bench", muscle: .chest), template("row", muscle: .upperBack)]

        screen.presenter.loadMuscleGroupsData()

        #expect(screen.presenter.muscleGroupCards.map(\.muscle) == [.upperBack, .chest])
        #expect(screen.presenter.muscleGroupCards.map(\.totalSets) == [3, 1])
    }

    // MARK: - + menu

    /// Each measurement in the + menu opens its own logger, and the menu offers all eighteen once.
    /// It used to open Body Metrics, three taps short of the logger.
    @Test("Test Log Measurement Opens That Measurement's Logger")
    func testLogMeasurementOpensThatMeasurementsLogger() {
        let screen = makeScreen()

        screen.presenter.onLogMeasurementPressed(kind: .leftCalf)

        #expect(screen.router.shown == ["logMeasurement-leftCalf"])
        let kinds = screen.presenter.measurementMenuSections.flatMap(\.kinds)
        #expect(kinds.count == BodyMeasurementKind.allCases.count)
        #expect(Set(kinds) == Set(BodyMeasurementKind.allCases))
    }

    /// A weigh-in that syncs after the tab first loaded is counted without a reload.
    @Test("Test A New Weigh-In Is Counted Without A Reload")
    func testANewWeighInIsCountedWithoutAReload() {
        let screen = makeScreen()
        #expect(screen.presenter.weighInCountThisWeek == 0)

        screen.interactor.bodyMeasurements = [weighIn(id: "today", daysAgo: 0, weightKg: 72)]

        #expect(screen.presenter.weighInCountThisWeek == 1)
        #expect(screen.presenter.weighInContributionData.last == 1.0)
    }
}
