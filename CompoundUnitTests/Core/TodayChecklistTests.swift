//
//  TodayChecklistTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// Today's checklist, the getting-started card, friends who trained and the weekly review card.
@MainActor
struct TodayChecklistTests {

    // MARK: - Building the checklist

    private func build(
        training: TodayChecklist.Training = .planned(name: "Push Day"),
        calories: Double = 0,
        protein: Double = 0,
        calorieTarget: Double? = 2_000,
        proteinTarget: Double? = 150,
        meals: Int = 0,
        weighIn: TodayChecklist.WeighIn = .init(latestKg: nil, isToday: false, weekChangeKg: nil, goalWeeklyChangeKg: nil),
        steps: TodayChecklist.Steps = .init(today: 0, goal: 8_000, hasStepData: false)
    ) -> TodayChecklist {
        TodayChecklist.build(
            training: training,
            nutrition: .init(calories: calories, proteinGrams: protein, calorieTarget: calorieTarget, proteinTarget: proteinTarget, mealsLoggedToday: meals),
            weighIn: weighIn,
            steps: steps,
            weightUnit: .kilograms,
            locale: Locale(identifier: "en_US")
        )
    }

    private func item(_ kind: TodayChecklist.Kind, in checklist: TodayChecklist) -> TodayChecklist.Item? {
        checklist.items.first { $0.kind == kind }
    }

    /// A rest day is the training done; with no plan and nothing logged the item is left out, so
    /// someone training without a plan can still complete the day.
    @Test("Test Training Is Done By A Workout Or A Rest Day And Absent Without A Plan")
    func testTrainingStates() {
        #expect(item(.training, in: build(training: .done(name: "Legs")))?.isDone == true)
        #expect(item(.training, in: build(training: .restDay))?.isDone == true)
        #expect(item(.training, in: build(training: .planned(name: "Legs")))?.isDone == false)
        #expect(item(.training, in: build(training: .nothingPlanned)) == nil)
    }

    /// Calories within 10% of target and protein reached; either missing leaves it undone.
    @Test("Test Nutrition Needs Calories In The Band And Protein Reached")
    func testNutritionRule() {
        #expect(item(.nutrition, in: build(calories: 1_950, protein: 150))?.isDone == true)
        #expect(item(.nutrition, in: build(calories: 1_700, protein: 160))?.isDone == false)
        #expect(item(.nutrition, in: build(calories: 2_300, protein: 160))?.isDone == false)
        #expect(item(.nutrition, in: build(calories: 2_000, protein: 120))?.isDone == false)
        #expect(item(.nutrition, in: build(calories: 1_450, protein: 110))?.detail == "1,450 / 2,000 kcal · 110 g / 150 g protein")
    }

    /// No diet plan means no target to hit: logging the day's food is the job.
    @Test("Test Without A Plan Logging A Meal Completes Nutrition")
    func testNutritionWithoutPlan() {
        #expect(item(.nutrition, in: build(calorieTarget: nil, meals: 0))?.isDone == false)
        #expect(item(.nutrition, in: build(calories: 600, calorieTarget: nil, meals: 1))?.isDone == true)
    }

    @Test("Test The Weigh In Shows The Week's Change And The Goal Pace")
    func testWeighIn() {
        let checklist = build(weighIn: .init(latestKg: 82.4, isToday: true, weekChangeKg: -0.4, goalWeeklyChangeKg: -0.5))
        #expect(item(.weighIn, in: checklist)?.isDone == true)
        #expect(item(.weighIn, in: checklist)?.detail == "82.4 kg · −0.4 kg this week · goal −0.5 kg/wk")
        #expect(item(.weighIn, in: build())?.isDone == false)
    }

    @Test("Test Steps Appear Only With Health Data And Complete At The Goal")
    func testSteps() {
        #expect(item(.steps, in: build()) == nil)
        #expect(item(.steps, in: build(steps: .init(today: 6_000, goal: 8_000, hasStepData: true)))?.isDone == false)
        #expect(item(.steps, in: build(steps: .init(today: 8_000, goal: 8_000, hasStepData: true)))?.isDone == true)
    }

    @Test("Test The Day Is Complete When Every Item Is Done")
    func testDayComplete() {
        let partial = build(training: .restDay, calories: 2_000, protein: 150)
        #expect(partial.doneCount == 2)
        #expect(!partial.isComplete)

        let complete = build(
            training: .restDay, calories: 2_000, protein: 150,
            weighIn: .init(latestKg: 80, isToday: true, weekChangeKg: nil, goalWeeklyChangeKg: nil)
        )
        #expect(complete.isComplete)
    }

    // MARK: - Weight trend

    @Test("Test The Weekly Change Is From The Last Weigh In A Week Before The Latest")
    func testWeightTrend() {
        let day = { (offset: Int) in Date(timeIntervalSince1970: 1_780_000_000).addingTimeInterval(Double(offset) * 86_400) }
        let entries = [
            BodyMeasurementEntry(authorId: "me", weightKg: 81.0, date: day(0)),
            BodyMeasurementEntry(authorId: "me", weightKg: 80.8, date: day(2)),
            BodyMeasurementEntry(authorId: "me", weightKg: 80.5, date: day(9)),
            BodyMeasurementEntry(authorId: "me", weightKg: 99, date: day(10), deletedAt: day(10))
        ]

        let trend = TodayChecklist.weightTrend(entries)

        #expect(trend.latest?.weightKg == 80.5)
        #expect(abs((trend.weekChangeKg ?? 0) - -0.3) < 0.001)
        #expect(TodayChecklist.weightTrend(Array(entries.prefix(2))).weekChangeKg == nil)
    }

    @Test("Test Signed Weights")
    func testSignedWeight() {
        #expect(TodayChecklist.signedWeight(0.3, unit: .kilograms) == "+0.3 kg")
        #expect(TodayChecklist.signedWeight(-0.4, unit: .kilograms) == "−0.4 kg")
        #expect(TodayChecklist.signedWeight(0, unit: .kilograms) == "0 kg")
    }

    // MARK: - Friends

    @Test("Test Friends Who Trained Today Are Named Once Each")
    func testSocialPulse() {
        let now = Date()
        let morning = Calendar.current.startOfDay(for: now).addingTimeInterval(60)
        let sam = DashboardFixture.user("sam", firstName: "Sam")
        let alex = DashboardFixture.user("alex", firstName: "Alex")
        let sessions = [
            DashboardFixture.session(id: "1", author: "sam", on: morning),
            DashboardFixture.session(id: "2", author: "sam", on: morning.addingTimeInterval(60)),
            DashboardFixture.session(id: "3", author: "alex", on: morning, isRestDay: true),
            DashboardFixture.session(id: "4", author: "stranger", on: morning),
            DashboardFixture.session(id: "5", author: "alex", on: morning.addingTimeInterval(-86_400 * 2))
        ]

        let names = TodaySocialPulse.namesTrainedToday(sessions: sessions, following: [sam, alex], now: now)

        #expect(names == ["Sam"])
        #expect(TodaySocialPulse.text(names: []) == nil)
        #expect(TodaySocialPulse.text(names: ["Sam", "Alex"]) == "Sam and Alex trained today")
        #expect(TodaySocialPulse.text(names: ["Sam", "Alex", "Jo", "Kim"]) == "Sam, Alex and 2 others trained today")
    }

    // MARK: - The presenter

    private struct Screen {
        let presenter: TodayPresenter
        let interactor: TodayPresenterTests.Interactor
        let router: TodayPresenterTests.Router
    }

    private func makeScreen() -> Screen {
        let interactor = TodayPresenterTests.Interactor()
        let router = TodayPresenterTests.Router()
        let presenter = TodayPresenter(interactor: interactor, router: router, defaults: TestManagers.scratchDefaults("today"))
        return Screen(presenter: presenter, interactor: interactor, router: router)
    }

    private var earlyToday: Date { Calendar.current.startOfDay(for: .now).addingTimeInterval(60) }

    /// Without a plan the item starts an empty workout; once one is finished it opens the summary.
    @Test("Test A Finished Workout Opens Its Summary From The Checklist")
    func testTrainingItemRoutes() async {
        let screen = makeScreen()
        screen.presenter.onChecklistItemPressed(.training)
        #expect(await TestManagers.eventually { screen.router.shown == ["workoutTracker"] })
        #expect(screen.interactor.startedBlankCount == 1)

        let done = makeScreen()
        done.interactor.workoutSessions = [DashboardFixture.session(id: "s", author: "me", on: earlyToday)]
        done.presenter.onChecklistItemPressed(.training)
        #expect(done.router.shown == ["sessionDetail"])
        #expect(done.interactor.trackedEventNames.contains("TodayView_ChecklistItem_Press"))
    }

    @Test("Test The Weigh In Item Logs A Weight Until One Is Logged Today")
    func testWeighInRoutes() {
        let screen = makeScreen()
        screen.presenter.onChecklistItemPressed(.weighIn)
        #expect(screen.router.shown == ["logWeight"])

        screen.interactor.bodyMeasurements = [BodyMeasurementEntry(authorId: "me", weightKg: 80, date: earlyToday)]
        screen.presenter.onChecklistItemPressed(.weighIn)
        #expect(screen.router.shown == ["logWeight", "scaleWeight"])

        screen.presenter.onChecklistItemPressed(.steps)
        #expect(screen.router.shown.last == "steps")
    }

    @Test("Test Choosing A Step Goal Saves It")
    func testStepGoal() async {
        let screen = makeScreen()
        #expect(screen.presenter.stepGoal == TodayChecklist.defaultStepGoal)

        screen.presenter.onStepGoalSelected(10_000)

        #expect(await TestManagers.eventually { screen.interactor.savedAnalyticsSettings.last?.dailyStepGoal == 10_000 })
        #expect(screen.presenter.stepGoal == 10_000)
    }

    /// Celebrated once a day, however often Today redraws a completed day.
    @Test("Test A Completed Day Is Celebrated Once")
    func testDayCompleteOnce() {
        let screen = makeScreen()

        screen.presenter.onChecklistCompletionChanged(isComplete: true)
        screen.presenter.onChecklistCompletionChanged(isComplete: true)
        screen.presenter.onChecklistCompletionChanged(isComplete: false)

        #expect(screen.interactor.trackedEventNames.filter { $0 == "TodayView_DayComplete" }.count == 1)
    }

    @Test("Test Getting Started Shows Until Done Or Hidden")
    func testStarter() {
        let screen = makeScreen()
        #expect(screen.presenter.showsStarter)
        #expect(screen.presenter.starter.remaining.count == TodayStarter.Step.allCases.count)

        screen.interactor.stravaIsConnected = true
        #expect(!screen.presenter.starter.remaining.contains(.strava))

        screen.presenter.onStarterStepPressed(.firstMeal)
        #expect(screen.router.shown == ["addMeal"])

        screen.presenter.onStarterDismissed()
        #expect(!screen.presenter.showsStarter)
    }

    /// Last week's review stays offered until it is opened, and only when last week had something.
    @Test("Test The Weekly Review Card Stays Until Opened")
    func testWeeklyReviewCard() {
        let screen = makeScreen()
        #expect(!screen.presenter.showsWeeklyReviewCard)

        let lastWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: .now) ?? .now
        screen.interactor.workoutSessions = [DashboardFixture.session(id: "w", author: "me", on: lastWeek)]
        #expect(screen.presenter.showsWeeklyReviewCard)

        screen.presenter.onWeeklyReviewPressed()
        #expect(screen.router.shown == ["weeklyReview"])
        #expect(!screen.presenter.showsWeeklyReviewCard)
    }

    @Test("Test Friends Who Trained Open Social")
    func testSocialPulseTracked() {
        let screen = makeScreen()
        screen.interactor.followingUsers = [DashboardFixture.user("sam", firstName: "Sam")]
        screen.interactor.followingWorkoutSessions = [DashboardFixture.session(id: "1", author: "sam", on: earlyToday)]

        #expect(screen.presenter.socialPulseText == "Sam trained today")
        screen.presenter.onSocialPulsePressed()
        #expect(screen.interactor.trackedEventNames.contains("TodayView_SocialPulse_Press"))
    }
}
