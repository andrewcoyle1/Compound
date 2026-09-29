//
//  WeeklyReviewTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The Weekly Review's numbers and wording. The week under review is Monday 9 to Sunday 15 March
/// 2026, on a Monday-first calendar in UTC so the buckets do not move with the machine.
@MainActor
struct WeeklyReviewTests {

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }()

    static func date(day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour)) ?? .distantPast
    }

    private let week = Self.date(day: 11)

    private func set(reps: Int = 5, weightKg: Double = 100, rpe: Double? = nil, isWarmup: Bool = false) -> WorkoutSetModel {
        WorkoutSetModel(
            id: UUID().uuidString, authorId: "me", index: 1, reps: reps, weightKg: weightKg, rpe: rpe,
            isWarmup: isWarmup, completedAt: Self.date(day: 1), dateCreated: Self.date(day: 1)
        )
    }

    private func exercise(_ name: String, _ sets: [WorkoutSetModel]) -> WorkoutExerciseModel {
        WorkoutExerciseModel(id: UUID().uuidString, authorId: "me", templateId: name, name: name, trackingMode: .weightReps, index: 1, sets: sets)
    }

    private func session(_ id: String, day: Int, author: String = "me", _ exercises: WorkoutExerciseModel...) -> WorkoutSessionModel {
        DashboardFixture.session(id: id, author: author, on: Self.date(day: day), exercises: exercises)
    }

    private func template(_ name: String, _ muscles: [Muscles: MuscleTargetType]) -> ExerciseModel {
        ExerciseModel(
            id: name, authorId: "me", name: name, trackableMetrics: [], type: nil, laterality: nil,
            muscleGroups: muscles, isBodyweight: false, rangeOfMotion: 0, stability: 0,
            bodyWeightContribution: 0, alternateNames: []
        )
    }

    private func weighIn(_ kilograms: Double, day: Int, deleted: Bool = false) -> BodyMeasurementEntry {
        BodyMeasurementEntry(authorId: "me", weightKg: kilograms, date: Self.date(day: day), deletedAt: deleted ? Self.date(day: day) : nil)
    }

    private func meal(_ calories: Double, day: Int) -> MealLogModel {
        let item = MealItemModel(
            itemId: UUID().uuidString, sourceType: .ingredient, sourceId: "x", displayName: "Food",
            amount: 1, unit: "serving", nutrients: NutrientMap([.calories: calories])
        )
        return MealLogModel(authorId: "me", dayKey: "\(day)", date: Self.date(day: day), items: [item])
    }

    private func build(
        sessions: [WorkoutSessionModel] = [],
        measurements: [BodyMeasurementEntry] = [],
        meals: [MealLogModel] = [],
        goal: Int = 3,
        templates: [String: ExerciseModel] = [:],
        dailyTargets: [DailyMacroTarget] = []
    ) -> WeeklyReview {
        WeeklyReview.build(
            sessions: sessions, measurements: measurements, meals: meals, week: week, userId: "me",
            goal: goal, templates: templates, dailyTargets: dailyTargets, calendar: Self.calendar
        )
    }

    // MARK: - Sessions and volume

    @Test("Test Only The User's Sessions In The Week Count")
    func testOnlyTheUsersSessionsInTheWeekCount() {
        let review = build(sessions: [
            session("a", day: 9), session("b", day: 15),
            session("last-week", day: 8), session("next-week", day: 16), session("friend", day: 10, author: "friend")
        ])
        #expect(review.sessionCount == 2)
        #expect(review.sessionsText == "2 of 3")
    }

    @Test("Test Volume Compares With Last Week And Skips Warm-Ups")
    func testVolumeComparesWithLastWeekAndSkipsWarmUps() {
        let review = build(sessions: [
            session("last", day: 3, exercise("Bench", [set(reps: 10, weightKg: 100)])),
            session("this", day: 10, exercise("Bench", [set(reps: 11, weightKg: 100), set(reps: 10, weightKg: 50, isWarmup: true)]))
        ])
        #expect(review.volumeKg == 1100)
        #expect(review.previousVolumeKg == 1000)
        #expect(review.volumeChangeText == "+10% vs last week")
    }

    @Test("Test No Volume Last Week Has No Comparison")
    func testNoVolumeLastWeekHasNoComparison() {
        let review = build(sessions: [session("this", day: 10, exercise("Bench", [set()]))])
        #expect(review.volumeChange == nil)
        #expect(review.volumeChangeText == nil)
    }

    // MARK: - Muscles, records, RPE

    @Test("Test Sets Per Muscle Count Secondary Muscles At Half And Sort Most First")
    func testSetsPerMuscle() {
        let templates = ["Bench": template("Bench", [.chest: .primary, .triceps: .secondary])]
        let review = build(
            sessions: [session("a", day: 10, exercise("Bench", [set(), set(), set(isWarmup: true)]))],
            templates: templates
        )
        #expect(review.setsPerMuscle == [
            WeeklyReview.MuscleSets(muscle: .chest, sets: 2),
            WeeklyReview.MuscleSets(muscle: .triceps, sets: 1)
        ])
    }

    @Test("Test A Lift Beaten Twice In The Week Lists Its Latest Record Once")
    func testALiftBeatenTwiceListsItsLatestRecordOnce() {
        let review = build(sessions: [
            session("old", day: 2, exercise("Bench", [set(weightKg: 90)]), exercise("Squat", [set(weightKg: 140)])),
            session("mon", day: 9, exercise("Bench", [set(weightKg: 95)])),
            session("thu", day: 12, exercise("Bench", [set(weightKg: 100)]), exercise("Squat", [set(weightKg: 150)]))
        ])
        #expect(review.personalRecords.map { "\($0.exerciseName) \($0.detail)" } == ["Bench 100 kg × 5", "Squat 150 kg × 5"])
    }

    @Test("Test Average RPE Uses Only Sets That Recorded One")
    func testAverageRPE() {
        let tracked = build(sessions: [session("a", day: 10, exercise("Bench", [set(rpe: 7), set(rpe: 8), set()]))])
        #expect(tracked.averageRPE == 7.5)
        #expect(tracked.averageRPEText == "7.5")

        let untracked = build(sessions: [session("a", day: 10, exercise("Bench", [set()]))])
        #expect(untracked.averageRPE == nil)
    }

    // MARK: - Weight

    @Test("Test Weight Change Is From The Last Weigh-In Before The Week")
    func testWeightChangeFromBeforeTheWeek() {
        let review = build(measurements: [
            weighIn(80, day: 5), weighIn(79.5, day: 7), weighIn(79.2, day: 10), weighIn(79, day: 14), weighIn(70, day: 13, deleted: true)
        ])
        #expect(review.latestWeightKg == 79)
        #expect(review.weightChangeKg.map { abs($0 - -0.5) < 0.0001 } == true)
        #expect(review.weightText == "79 kg (−0.5 kg)")
    }

    @Test("Test Without Earlier Weigh-Ins The Change Is Within The Week")
    func testWeightChangeWithinTheWeek() {
        let one = build(measurements: [weighIn(80, day: 10)])
        #expect(one.weightChangeKg == nil)
        #expect(one.weightText == "80 kg")

        let two = build(measurements: [weighIn(80, day: 10), weighIn(81, day: 12)])
        #expect(two.weightChangeKg == 1)
    }

    @Test("Test No Weigh-In That Week Shows No Weight")
    func testNoWeighInShowsNoWeight() {
        #expect(build(measurements: [weighIn(80, day: 3)]).weightText == nil)
    }

    // MARK: - Nutrition

    @Test("Test Adherence Counts Logged Days Within Ten Percent Of That Day's Target")
    func testAdherence() {
        // Monday first: day 9 is a Monday (2000), day 10 a Tuesday (2500).
        let targets = [2000.0, 2500, 2000, 2000, 2000, 2000, 2000].map {
            DailyMacroTarget(calories: $0, proteinGrams: 0, carbGrams: 0, fatGrams: 0)
        }
        let review = build(
            meals: [meal(1000, day: 9), meal(1100, day: 9), meal(2000, day: 10), meal(2000, day: 11), meal(5000, day: 2)],
            dailyTargets: targets
        )
        #expect(review.nutrition == WeeklyReview.NutritionAdherence(daysOnTarget: 2, daysLogged: 3))
        #expect(review.nutritionText == "2 of 3 logged days on target")
    }

    @Test("Test Without Targets There Is No Adherence")
    func testNoTargetsNoAdherence() {
        #expect(build(meals: [meal(2000, day: 10)]).nutrition == nil)
    }

    // MARK: - Takeaway

    @Test("Test Takeaway")
    func testTakeaway() {
        #expect(build().takeaway == "No sessions logged this week.")

        let prWeek = build(sessions: [
            session("old", day: 2, exercise("Bench", [set(weightKg: 90)])),
            session("a", day: 9), session("b", day: 10), session("c", day: 11, exercise("Bench", [set(weightKg: 100)]))
        ])
        #expect(prWeek.takeaway == "Goal hit and 1 PR set. Great week.")

        #expect(build(sessions: [session("a", day: 9)], goal: 1).takeaway == "Goal hit: 1 of 1 sessions.")

        let volumeUp = build(sessions: [
            session("last", day: 3, exercise("Bench", [set(reps: 10, weightKg: 50)])),
            session("this", day: 10, exercise("Bench", [set(reps: 10, weightKg: 60)]))
        ])
        #expect(volumeUp.takeaway == "Volume up 20% on last week.")

        #expect(build(sessions: [session("a", day: 9)]).takeaway == "2 more sessions would have hit your goal.")
    }

    // MARK: - Presenter

    final class Interactor: SpyGlobalInteractor, WeeklyReviewInteractor {
        var currentUser: UserModel? = DashboardFixture.user("me")
        var workoutSessions: [WorkoutSessionModel] = []
        var bodyMeasurements: [BodyMeasurementEntry] = []
        var userMeals: [MealLogModel] = []
        var currentDietPlan: DietPlan?
        var allExercises: [ExerciseModel] = []
    }

    final class Router: WeeklyReviewRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var sharedItems: [[Any]] = []
        private(set) var alertTitles: [String] = []

        func showShareSheet(items: [Any]) { sharedItems.append(items) }
        func showDevSettingsView() { }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    @Test("Test Opens On Last Week On A Monday And This Week Otherwise")
    func testOpeningWeek() {
        let monday = WeeklyReviewPresenter(interactor: Interactor(), router: Router(), calendar: Self.calendar, now: { Self.date(day: 16) })
        #expect(Self.calendar.isDate(monday.week, equalTo: Self.date(day: 12), toGranularity: .weekOfYear))
        #expect(monday.canShowNextWeek)

        let wednesday = WeeklyReviewPresenter(interactor: Interactor(), router: Router(), calendar: Self.calendar, now: { Self.date(day: 18) })
        #expect(Self.calendar.isDate(wednesday.week, equalTo: Self.date(day: 18), toGranularity: .weekOfYear))
        #expect(!wednesday.canShowNextWeek)
    }

    @Test("Test Week Navigation Stops At The Current Week")
    func testWeekNavigation() {
        let presenter = WeeklyReviewPresenter(interactor: Interactor(), router: Router(), calendar: Self.calendar, now: { Self.date(day: 18) })
        presenter.onNextWeekPressed()
        #expect(Self.calendar.isDate(presenter.week, equalTo: Self.date(day: 18), toGranularity: .weekOfYear))
        presenter.onPreviousWeekPressed()
        #expect(Self.calendar.isDate(presenter.week, equalTo: Self.date(day: 11), toGranularity: .weekOfYear))
        presenter.onNextWeekPressed()
        #expect(Self.calendar.isDate(presenter.week, equalTo: Self.date(day: 18), toGranularity: .weekOfYear))
    }

    @Test("Test The Review Reads The User's Data And Goal")
    func testReviewReadsInteractor() {
        let interactor = Interactor()
        interactor.currentUser = UserModel(userId: "me", weeklySessionGoal: 2)
        interactor.workoutSessions = [session("a", day: 17), session("b", day: 18)]
        let presenter = WeeklyReviewPresenter(interactor: interactor, router: Router(), calendar: Self.calendar, now: { Self.date(day: 18) })
        #expect(presenter.review.sessionsText == "2 of 2")
    }

    @Test("Test Share Renders An Image Into The Share Sheet")
    func testShare() {
        let router = Router()
        let interactor = Interactor()
        let presenter = WeeklyReviewPresenter(interactor: interactor, router: router, calendar: Self.calendar, now: { Self.date(day: 18) })
        presenter.onSharePressed()
        #expect(router.sharedItems.count == 1)
        #expect(router.sharedItems.first?.first is UIImage)
        #expect(!presenter.isSharing)
        #expect(interactor.trackedEventNames.contains("WeeklyReviewView_Share_Pressed"))
    }

    @Test("Test The Dashboard Card Opens The Weekly Review")
    func testDashboardCardRoutes() {
        let router = DashboardFeedPresenterTests.Router()
        let presenter = DashboardPresenter(interactor: DashboardFeedPresenterTests.Interactor(), router: router)
        presenter.onWeeklyReviewPressed()
        #expect(router.shown == ["weeklyReview"])
    }
}
