//
//  TodayPresenterTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// Today: the user's own workout, food, weigh-in and whatever is due this week.
@MainActor
struct TodayPresenterTests {

    /// Internal rather than private so `WeeklyReviewTests` can share the doubles.
    final class Interactor: SpyGlobalInteractor, TodayInteractor {
        var userId: String? = "me"
        var userImageUrl: String?
        var currentUser: UserModel? = DashboardFixture.user("me")
        var activeMesocycle: Mesocycle?
        var currentMacrocycle: Macrocycle?
        var workoutSessions: [WorkoutSessionModel] = []
        private(set) var repeatPlanCount = 0

        /// The mesocycle followed from the start of time, so every fixture session counts.
        var activeMesocycleRun: MesocycleSchedule.Run? {
            activeMesocycle.map { MesocycleSchedule.Run(mesocycle: $0, startedAt: .distantPast) }
        }
        func repeatCurrentMacrocycle() async throws { repeatPlanCount += 1 }
        var activeSession: WorkoutSessionModel?
        var draftMeal: MealLogModel?
        var bodyMeasurements: [BodyMeasurementEntry] = []
        var checkInState: CheckInState = .notDue
        var totals: DailyMacroTarget?
        var target: DailyMacroTarget?
        var skipError: Error?
        private(set) var totalsDayKeys: [String] = []
        private(set) var deletedDraftCount = 0
        private(set) var startedBlankCount = 0
        private(set) var skippedWeeks: [Date] = []

        // MARK: - ReminderOfferInteractor
        var privateUserSettings = PrivateUserSettings()
        var currentStreakData = CurrentStreakData(streakKey: "workout")
        func canRequestNotificationAuthorisation() async -> Bool { false }
        func requestPushAuthorisation() async throws -> Bool { true }
        func setMealReminders(isEnabled: Bool) async throws { }
        func setStreakReminder(isEnabled: Bool) async throws { }

        func startBlankWorkout() async throws { startedBlankCount += 1 }
        func deleteActiveSession() throws { activeSession = nil }
        func deleteDraftMeal() throws {
            deletedDraftCount += 1
            draftMeal = nil
        }
        func getDailyTotals(dayKey: String) throws -> DailyMacroTarget {
            totalsDayKeys.append(dayKey)
            guard let totals else { throw DashboardTestError.failed }
            return totals
        }
        func getDailyTarget(for date: Date, userId: String) async throws -> DailyMacroTarget? { target }
        func markCheckInSkipped(weekStart: Date) async throws {
            if let skipError { throw skipError }
            skippedWeeks.append(weekStart)
        }
    }

    /// `showDevSettingsView()` is declared unguarded: the test target builds without `-DDEV`.
    final class Router: TodayRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var alertTitles: [String] = []
        private(set) var addMealDelegates: [AddMealDelegate] = []

        func showDevSettingsView() { shown.append("devSettings") }
        func showProfileViewZoom(transitionId: String?, namespace: Namespace.ID) { shown.append("profile") }
        func showWorkoutTrackerView() { shown.append("workoutTracker") }
        func showMesocycleLibraryView() { shown.append("programs") }
        func showLogWeightView() { shown.append("logWeight") }
        func showCheckInView(delegate: CheckInDelegate) { shown.append("checkIn") }
        func showWeeklyReviewView() { shown.append("weeklyReview") }
        func showAddMealView(delegate: AddMealDelegate) {
            shown.append("addMeal")
            addMealDelegates.append(delegate)
        }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
        func showConfirmationDialog(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
    }

    private struct Screen {
        let presenter: TodayPresenter
        let interactor: Interactor
        let router: Router
        let delegate = TodayDelegate()
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(presenter: TodayPresenter(interactor: interactor, router: router), interactor: interactor, router: router)
    }

    // MARK: Workout

    @Test("Test There Is No Todays Workout Without A Program")
    func testThereIsNoTodaysWorkoutWithoutAMesocycle() {
        let screen = makeScreen()

        #expect(screen.presenter.hasActiveMesocycle == false)
        #expect(screen.presenter.todaysWorkoutTemplate == nil)
    }

    /// With a mesocycle running, the card offers the next day plan in the rotation.
    @Test("Test An Active Program Offers Todays Workout")
    func testAnActiveMesocycleOffersTodaysWorkout() {
        let screen = makeScreen()
        let template = WorkoutTemplateModel(
            id: "push",
            authorId: "me",
            name: "Push",
            exercises: [WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)]
        )
        screen.interactor.activeMesocycle = Mesocycle(
            id: "program-1", authorId: "me", name: "Base", icon: "dumbbell", colour: "#FF0000", workoutTemplates: [template]
        )

        #expect(screen.presenter.hasActiveMesocycle)
        #expect(screen.presenter.todaysWorkoutTemplate?.id == "push")
    }

    /// Without a plan the card still offers a workout: an empty one, straight into the tracker.
    @Test("Test Start Empty Workout Starts One And Opens The Tracker")
    func testStartEmptyWorkoutStartsOneAndOpensTheTracker() async {
        let screen = makeScreen()

        screen.presenter.onStartEmptyWorkoutPressed()

        #expect(await TestManagers.eventually { screen.router.shown == ["workoutTracker"] })
        #expect(screen.interactor.startedBlankCount == 1)
    }

    @Test("Test Starting With A Workout Running Asks First")
    func testStartingWithAWorkoutRunningAsksFirst() async {
        let screen = makeScreen()
        screen.interactor.activeSession = WorkoutSessionModel(authorId: "me", name: "Live", dateCreated: .now, exercises: [])

        screen.presenter.onStartEmptyWorkoutPressed()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(screen.router.alertTitles == ["Active Workout"])
        #expect(screen.interactor.startedBlankCount == 0)
    }

    // MARK: Nutrition

    /// Filled on appear, so opening the tab after logging breakfast shows breakfast.
    @Test("Test Appearing Loads Todays Nutrition Totals And Target")
    func testAppearingLoadsTodaysNutritionTotalsAndTarget() async {
        let screen = makeScreen()
        screen.interactor.totals = DailyMacroTarget(calories: 900, proteinGrams: 50, carbGrams: 80, fatGrams: 30)
        screen.interactor.target = DailyMacroTarget.mock

        screen.presenter.onViewAppear(delegate: screen.delegate)
        await TestManagers.eventually { screen.presenter.nutritionTarget != nil }

        #expect(screen.presenter.nutritionTotals?.calories == 900)
        #expect(screen.presenter.nutritionTarget?.calories == DailyMacroTarget.mock.calories)
        #expect(screen.interactor.totalsDayKeys == [Date().dayKey])
    }

    @Test("Test A Failed Totals Read Leaves The Card Empty")
    func testAFailedTotalsReadLeavesTheCardEmpty() {
        let screen = makeScreen()
        screen.interactor.totals = nil

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.presenter.nutritionTotals == nil)
    }

    @Test("Test Logging A Meal Opens A New Meal For Today")
    func testLoggingAMealOpensANewMealForToday() {
        let screen = makeScreen()

        screen.presenter.onLogMealPressed()

        #expect(screen.router.shown == ["addMeal"])
        #expect(screen.router.addMealDelegates.first?.mealLog.authorId == "me")
        #expect(screen.router.addMealDelegates.first?.mealLog.dayKey == Date().dayKey)
    }

    /// A half-finished meal is unsaved work, so the user is asked before a second one starts.
    @Test("Test A Draft Meal Asks Before Starting Another")
    func testADraftMealAsksBeforeStartingAnother() {
        let screen = makeScreen()
        screen.interactor.draftMeal = MealLogModel(authorId: "me", dayKey: Date().dayKey, date: Date(), items: [])

        screen.presenter.onLogMealPressed()

        #expect(screen.router.alertTitles == ["Draft Meal"])
        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.deletedDraftCount == 0)
    }

    @Test("Test Logging A Meal Does Nothing Without A Signed In User")
    func testLoggingAMealDoesNothingWithoutASignedInUser() {
        let screen = makeScreen()
        screen.interactor.currentUser = nil

        screen.presenter.onLogMealPressed()

        #expect(screen.router.shown.isEmpty)
    }

    // MARK: Weigh-in

    /// The latest live entry with a weight, in the user's unit; deleted and weightless entries skip.
    @Test("Test The Weigh In Card Shows The Latest Weight")
    func testTheWeighInCardShowsTheLatestWeight() {
        let screen = makeScreen()
        #expect(screen.presenter.latestWeightText == nil)

        screen.interactor.bodyMeasurements = [
            BodyMeasurementEntry(authorId: "me", weightKg: 80, date: DashboardFixture.date(day: 1)),
            BodyMeasurementEntry(authorId: "me", weightKg: 79.5, date: DashboardFixture.date(day: 3)),
            BodyMeasurementEntry(authorId: "me", weightKg: 70, date: DashboardFixture.date(day: 4), deletedAt: .now),
            BodyMeasurementEntry(authorId: "me", date: DashboardFixture.date(day: 5))
        ]

        #expect(screen.presenter.latestWeightText == Format.weight(kg: 79.5, unit: WeightUnitPreference.kilograms))
        #expect(screen.presenter.latestWeighInDate == DashboardFixture.date(day: 3))
        #expect(screen.presenter.hasWeighedInToday == false)
    }

    @Test("Test Log Weight Opens The Weight Logger")
    func testLogWeightOpensTheWeightLogger() {
        let screen = makeScreen()

        screen.presenter.onLogWeightPressed()

        #expect(screen.router.shown == ["logWeight"])
    }

    // MARK: Weekly check-in

    @Test("Test A Due Check In Is Offered And Opens")
    func testADueCheckInIsOfferedAndOpens() {
        let screen = makeScreen()
        let weekStart = DashboardFixture.date(day: 2)
        screen.interactor.checkInState = .due(weekStart: weekStart)

        screen.presenter.onViewAppear(delegate: screen.delegate)
        #expect(screen.presenter.dueCheckInWeekStart == weekStart)

        screen.presenter.onStartCheckInPressed()
        #expect(screen.router.shown == ["checkIn"])
    }

    /// Skipping hides the card at once and puts it back if the write fails.
    @Test("Test A Failed Skip Puts The Check In Back")
    func testAFailedSkipPutsTheCheckInBack() async {
        let screen = makeScreen()
        let weekStart = DashboardFixture.date(day: 2)
        screen.interactor.checkInState = .due(weekStart: weekStart)
        screen.interactor.skipError = DashboardTestError.failed
        screen.presenter.onViewAppear(delegate: screen.delegate)

        screen.presenter.onSkipCheckInPressed()
        #expect(screen.presenter.dueCheckInWeekStart == nil)

        #expect(await TestManagers.eventually { screen.presenter.dueCheckInWeekStart == weekStart })
    }

    @Test("Test Appearing And Disappearing Are Tracked")
    func testAppearingAndDisappearingAreTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: screen.delegate)
        screen.presenter.onViewDisappear(delegate: screen.delegate)

        #expect(screen.interactor.trackedScreenEventNames == ["TodayView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["TodayView_Disappear"])
    }

    // MARK: Streak reminder offer

    /// `ReminderOfferFlow.offerStreakReminderIfNeeded()` had no caller before this — decision 7c
    /// wires it to Today's appear, which is where the streak is seen to have grown.
    @Test("Test Reaching A Three Day Streak Offers The Reminder On Appear")
    func testReachingAThreeDayStreakOffersTheReminderOnAppear() {
        let key = ReminderOfferFlow.Offer.streakReminder.shownKey
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let screen = makeScreen()
        screen.interactor.currentStreakData = CurrentStreakData(streakKey: "workout", currentStreak: 3)

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.router.alertTitles == [String(localized: "Streak Reminder")])
    }

    /// Below the 3-day threshold, or already answered, nothing is offered.
    @Test("Test Below Threshold Or Already Answered Offers Nothing")
    func testBelowThresholdOrAlreadyAnsweredOffersNothing() {
        let key = ReminderOfferFlow.Offer.streakReminder.shownKey
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let screen = makeScreen()
        screen.interactor.currentStreakData = CurrentStreakData(streakKey: "workout", currentStreak: 2)
        screen.presenter.onViewAppear(delegate: screen.delegate)
        #expect(screen.router.alertTitles.isEmpty)

        let answeredScreen = makeScreen()
        answeredScreen.interactor.currentStreakData = CurrentStreakData(streakKey: "workout", currentStreak: 5)
        answeredScreen.interactor.privateUserSettings.socialPushStreakReminder = false
        answeredScreen.presenter.onViewAppear(delegate: answeredScreen.delegate)
        #expect(answeredScreen.router.alertTitles.isEmpty)
    }
}
