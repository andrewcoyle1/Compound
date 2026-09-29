//
//  AnalyticsExercisePresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// Fixtures for the screens derived from logged workouts.
///
/// Dates are fixed and none of them is today, so anything reaching for `Date()` instead of the day
/// it is describing lands outside the window and fails.
@MainActor
enum AnalyticsExerciseFixture {

    static func date(day: Int, month: Int = 3, year: Int = 2026, hour: Int = 17) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    static func exercise(id: String, name: String = "Bench Press", muscles: [Muscles: MuscleTargetType] = [:]) -> ExerciseModel {
        ExerciseModel(
            id: id,
            authorId: "author-1",
            name: name,
            trackableMetrics: [.weight, .reps],
            type: .compoundUpper,
            laterality: .bilateral,
            muscleGroups: muscles,
            isBodyweight: false,
            rangeOfMotion: 4,
            stability: 5,
            bodyWeightContribution: 0,
            alternateNames: []
        )
    }

    static func set(
        id: String,
        reps: Int? = 5,
        weightKg: Double? = 100,
        isWarmup: Bool = false,
        completed: Bool = true
    ) -> WorkoutSetModel {
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

    /// One exercise within a session: which template it was, and the sets logged against it.
    struct LoggedExercise {
        let templateId: String
        let name: String
        let sets: [WorkoutSetModel]

        init(templateId: String, name: String = "Bench Press", sets: [WorkoutSetModel]) {
            self.templateId = templateId
            self.name = name
            self.sets = sets
        }
    }

    static func session(
        id: String,
        day: Int,
        ended: Bool = true,
        isRestDay: Bool = false,
        exercises: [LoggedExercise] = []
    ) -> WorkoutSessionModel {
        let when = date(day: day)
        return WorkoutSessionModel(
            id: id,
            authorId: "author-1",
            name: "Push Day",
            dateCreated: when,
            endedAt: ended ? when : nil,
            exercises: exercises.enumerated().map { index, item in
                WorkoutExerciseModel(
                    id: "we-\(id)-\(index)",
                    authorId: "author-1",
                    templateId: item.templateId,
                    name: item.name,
                    trackingMode: .weightReps,
                    index: index + 1,
                    sets: item.sets
                )
            },
            isRestDay: isRestDay
        )
    }
}

/// The Exercises screen: one card per exercise, showing its estimated one-rep max.
@MainActor
struct AnalyticsExerciseAnalyticsTests {

    private final class Interactor: SpyGlobalInteractor, ExerciseAnalyticsInteractor {
        var auth: UserAuthInfo?
        var workoutSessions: [WorkoutSessionModel] = []
        var systemExercises: [ExerciseModel] = []
        var userExercises: [ExerciseModel] = []
        var preferences: [String: ExerciseUnitPreference] = [:]

        func getPreference(templateId: String) -> ExerciseUnitPreference {
            preferences[templateId] ?? ExerciseUnitPreference(exerciseModelId: templateId)
        }
    }

    private final class Router: ExerciseAnalyticsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var openedTemplateIds: [String] = []

        func showExerciseDetailView(templateId: String, name: String, delegate: ExerciseDetailDelegate, themeColor: Color?) {
            openedTemplateIds.append(templateId)
        }
    }

    private struct Screen {
        let presenter: ExerciseAnalyticsPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(
        sessions: [WorkoutSessionModel] = [],
        userExercises: [ExerciseModel] = [],
        systemExercises: [ExerciseModel] = [],
        preferences: [String: ExerciseUnitPreference] = [:]
    ) -> Screen {
        let interactor = Interactor()
        interactor.workoutSessions = sessions
        interactor.userExercises = userExercises
        interactor.systemExercises = systemExercises
        interactor.preferences = preferences
        let router = Router()
        return Screen(
            presenter: ExerciseAnalyticsPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// A workout still in progress has not produced a one-rep max yet: its half-finished sets must
    /// not move the number the user reads as their current best.
    @Test("Test A Workout In Progress Does Not Count")
    func testAWorkoutInProgressDoesNotCount() async throws {
        let screen = makeScreen(
            sessions: [
                AnalyticsExerciseFixture.session(id: "done", day: 4, exercises: [
                    AnalyticsExerciseFixture.LoggedExercise(templateId: "bench", sets: [AnalyticsExerciseFixture.set(id: "a", reps: 1, weightKg: 100)])
                ]),
                AnalyticsExerciseFixture.session(id: "live", day: 5, ended: false, exercises: [
                    AnalyticsExerciseFixture.LoggedExercise(templateId: "bench", sets: [AnalyticsExerciseFixture.set(id: "b", reps: 1, weightKg: 200)])
                ])
            ],
            userExercises: [AnalyticsExerciseFixture.exercise(id: "bench")]
        )

        await screen.presenter.loadData()
        let card = try #require(screen.presenter.exerciseCards.first)

        #expect(card.latest1RM == 100)
    }

    /// Warm-ups and sets never ticked off are not evidence of strength.
    @Test("Test Warm Up And Unfinished Sets Are Ignored")
    func testWarmUpAndUnfinishedSetsAreIgnored() async throws {
        let screen = makeScreen(
            sessions: [
                AnalyticsExerciseFixture.session(id: "s", day: 4, exercises: [
                    AnalyticsExerciseFixture.LoggedExercise(templateId: "bench", sets: [
                        AnalyticsExerciseFixture.set(id: "warm", reps: 1, weightKg: 300, isWarmup: true),
                        AnalyticsExerciseFixture.set(id: "skipped", reps: 1, weightKg: 250, completed: false),
                        AnalyticsExerciseFixture.set(id: "done", reps: 1, weightKg: 100)
                    ])
                ])
            ],
            userExercises: [AnalyticsExerciseFixture.exercise(id: "bench")]
        )

        await screen.presenter.loadData()

        #expect(try #require(screen.presenter.exerciseCards.first).latest1RM == 100)
    }

    /// The card is drawn in the unit that exercise is logged in — a lifter who works in pounds
    /// reads pounds on the card and in its caption.
    @Test("Test A Card Is Drawn In The Exercises Own Unit")
    func testACardIsDrawnInTheExercisesOwnUnit() async throws {
        let screen = makeScreen(
            sessions: [
                AnalyticsExerciseFixture.session(id: "s", day: 4, exercises: [
                    AnalyticsExerciseFixture.LoggedExercise(templateId: "bench", sets: [AnalyticsExerciseFixture.set(id: "a", reps: 1, weightKg: 100)])
                ])
            ],
            userExercises: [AnalyticsExerciseFixture.exercise(id: "bench")],
            preferences: ["bench": ExerciseUnitPreference(exerciseModelId: "bench", weightUnit: .pounds)]
        )

        await screen.presenter.loadData()
        let card = try #require(screen.presenter.exerciseCards.first)

        #expect(abs(card.latest1RM - 220.462) < 0.01)
        #expect(card.unitText == "lbs")
        #expect((card.sparklineData.first?.value ?? 0) > 220)
    }

    /// An exercise's card reads that exercise's sets. A heavy squat must not raise the bench
    /// press's estimate.
    @Test("Test Each Card Reads Only Its Own Exercise")
    func testEachCardReadsOnlyItsOwnExercise() async throws {
        let screen = makeScreen(
            sessions: [
                AnalyticsExerciseFixture.session(id: "s", day: 4, exercises: [
                    AnalyticsExerciseFixture.LoggedExercise(templateId: "bench", sets: [AnalyticsExerciseFixture.set(id: "a", reps: 1, weightKg: 100)]),
                    AnalyticsExerciseFixture.LoggedExercise(templateId: "squat", name: "Squat", sets: [AnalyticsExerciseFixture.set(id: "b", reps: 1, weightKg: 200)])
                ])
            ],
            userExercises: [
                AnalyticsExerciseFixture.exercise(id: "bench", name: "Bench Press"),
                AnalyticsExerciseFixture.exercise(id: "squat", name: "Squat")
            ]
        )

        await screen.presenter.loadData()

        let bench = try #require(screen.presenter.exerciseCards.first { $0.templateId == "bench" })
        let squat = try #require(screen.presenter.exerciseCards.first { $0.templateId == "squat" })
        #expect(bench.latest1RM == 100)
        #expect(squat.latest1RM == 200)
    }

    /// An exercise the user has never performed still gets a card, reading as having no data
    /// rather than a one-rep max of zero kilograms.
    @Test("Test An Unperformed Exercise Has No Figure")
    func testAnUnperformedExerciseHasNoFigure() async throws {
        let screen = makeScreen(userExercises: [AnalyticsExerciseFixture.exercise(id: "bench")])

        await screen.presenter.loadData()
        let card = try #require(screen.presenter.exerciseCards.first)

        #expect(card.latest1RM == 0)
        #expect(card.sparklineData.isEmpty)
    }

    /// The library is the user's exercises and the prebuilt ones, each appearing once and in
    /// alphabetical order — a user's edit of a prebuilt exercise must not list it twice.
    @Test("Test The Library Is Listed Once And In Order")
    func testTheLibraryIsListedOnceAndInOrder() async {
        let screen = makeScreen(
            userExercises: [AnalyticsExerciseFixture.exercise(id: "bench", name: "Bench Press")],
            systemExercises: [
                AnalyticsExerciseFixture.exercise(id: "bench", name: "Bench Press"),
                AnalyticsExerciseFixture.exercise(id: "squat", name: "Squat"),
                AnalyticsExerciseFixture.exercise(id: "arnold", name: "Arnold Press")
            ]
        )

        await screen.presenter.loadData()

        #expect(screen.presenter.exerciseCards.map(\.name) == ["Arnold Press", "Bench Press", "Squat"])
    }

    @Test("Test A Card Opens Its Own Exercise")
    func testACardOpensItsOwnExercise() {
        let screen = makeScreen()

        screen.presenter.onExercisePressed(templateId: "bench", name: "Bench Press", themeColor: nil)

        #expect(screen.router.openedTemplateIds == ["bench"])
    }

    @Test("Test Appearing Is Tracked")
    func testAppearingIsTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["ExerciseAnalyticsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["ExerciseAnalyticsView_Disappear"])
    }
}

/// The detail screen behind an exercise card: estimated one-rep max, by day.
@MainActor
struct AnalyticsExerciseDetailTests {

    private final class Interactor: ExerciseDetailInteractor {
        var auth: UserAuthInfo?
        var workoutSessions: [WorkoutSessionModel] = []
        var preferences: [String: ExerciseUnitPreference] = [:]

        func getPreference(templateId: String) -> ExerciseUnitPreference {
            preferences[templateId] ?? ExerciseUnitPreference(exerciseModelId: templateId)
        }
    }

    private final class Router: ExerciseDetailRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var didShowWorkouts = false

        func showWorkoutsView(delegate: WorkoutsDelegate) { didShowWorkouts = true }
    }

    private struct Screen {
        let presenter: ExerciseDetailPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(
        sessions: [WorkoutSessionModel] = [],
        unit: ExerciseWeightUnit = .kilograms
    ) -> Screen {
        let interactor = Interactor()
        interactor.workoutSessions = sessions
        interactor.preferences = ["bench": ExerciseUnitPreference(exerciseModelId: "bench", weightUnit: unit)]
        let router = Router()
        return Screen(
            presenter: ExerciseDetailPresenter(interactor: interactor, router: router, templateId: "bench", name: "Bench Press"),
            interactor: interactor,
            router: router
        )
    }

    private func benchSession(id: String, day: Int, sets: [WorkoutSetModel], ended: Bool = true) -> WorkoutSessionModel {
        AnalyticsExerciseFixture.session(id: id, day: day, ended: ended, exercises: [
            AnalyticsExerciseFixture.LoggedExercise(templateId: "bench", sets: sets)
        ])
    }

    // MARK: - The estimate

    /// A single at that weight is that weight: Epley only adds for the extra reps.
    @Test("Test A Single Is Its Own One Rep Max")
    func testASingleIsItsOwnOneRepMax() async throws {
        let screen = makeScreen(sessions: [
            benchSession(id: "s", day: 4, sets: [AnalyticsExerciseFixture.set(id: "a", reps: 1, weightKg: 100)])
        ])

        await screen.presenter.loadData()

        #expect(try #require(screen.presenter.entries.first).oneRMKg == 100)
    }

    /// Five at 100 estimates more than a single at 100 — the whole point of the estimate is that
    /// reps at a weight are worth more than one.
    @Test("Test Reps Raise The Estimate")
    func testRepsRaiseTheEstimate() async throws {
        let screen = makeScreen(sessions: [
            benchSession(id: "s", day: 4, sets: [AnalyticsExerciseFixture.set(id: "a", reps: 6, weightKg: 100)])
        ])

        await screen.presenter.loadData()

        #expect(try #require(screen.presenter.entries.first).oneRMKg == 120)
    }

    /// A day is worth its best set, not its last or its average — a back-off set after a top
    /// single must not pull the day down.
    @Test("Test A Day Is Worth Its Best Set")
    func testADayIsWorthItsBestSet() async throws {
        let screen = makeScreen(sessions: [
            benchSession(id: "s", day: 4, sets: [
                AnalyticsExerciseFixture.set(id: "top", reps: 1, weightKg: 120),
                AnalyticsExerciseFixture.set(id: "backoff", reps: 5, weightKg: 90)
            ])
        ])

        await screen.presenter.loadData()

        #expect(try #require(screen.presenter.entries.first).oneRMKg == 120)
    }

    /// Two sessions on one day are one point on the chart, at the better of the two. A chart with
    /// two points for one date draws a vertical line on that day.
    @Test("Test Two Sessions In A Day Are One Point")
    func testTwoSessionsInADayAreOnePoint() async {
        let screen = makeScreen(sessions: [
            benchSession(id: "morning", day: 4, sets: [AnalyticsExerciseFixture.set(id: "a", reps: 1, weightKg: 100)]),
            benchSession(id: "evening", day: 4, sets: [AnalyticsExerciseFixture.set(id: "b", reps: 1, weightKg: 110)])
        ])

        await screen.presenter.loadData()

        #expect(screen.presenter.entries.count == 1)
        #expect(screen.presenter.entries.first?.oneRMKg == 110)
    }

    /// Unfinished sets, warm-ups and sets with no weight carry no estimate, and a day left with
    /// nothing is not plotted at zero.
    @Test("Test A Day Of Warm Ups Alone Is Not Plotted")
    func testADayOfWarmUpsAloneIsNotPlotted() async {
        let screen = makeScreen(sessions: [
            benchSession(id: "s", day: 4, sets: [
                AnalyticsExerciseFixture.set(id: "warm", reps: 10, weightKg: 40, isWarmup: true),
                AnalyticsExerciseFixture.set(id: "skipped", reps: 5, weightKg: 100, completed: false),
                AnalyticsExerciseFixture.set(id: "bodyweight", reps: 10, weightKg: nil)
            ])
        ])

        await screen.presenter.loadData()

        #expect(screen.presenter.entries.isEmpty)
    }

    /// Another exercise's sets belong to another exercise's screen.
    @Test("Test Another Exercises Sets Are Ignored")
    func testAnotherExercisesSetsAreIgnored() async {
        let screen = makeScreen(sessions: [
            AnalyticsExerciseFixture.session(id: "s", day: 4, exercises: [
                AnalyticsExerciseFixture.LoggedExercise(templateId: "squat", name: "Squat", sets: [AnalyticsExerciseFixture.set(id: "a", reps: 1, weightKg: 200)])
            ])
        ])

        await screen.presenter.loadData()

        #expect(screen.presenter.entries.isEmpty)
    }

    @Test("Test A Workout In Progress Does Not Count")
    func testAWorkoutInProgressDoesNotCount() async {
        let screen = makeScreen(sessions: [
            benchSession(id: "live", day: 4, sets: [AnalyticsExerciseFixture.set(id: "a", reps: 1, weightKg: 100)], ended: false)
        ])

        await screen.presenter.loadData()

        #expect(screen.presenter.entries.isEmpty)
    }

    // MARK: - Reading the screen

    /// Rows read newest first while the chart runs oldest to newest, so progress reads left to
    /// right and the most recent session is at the top of the list.
    @Test("Test Rows Read Newest First And The Chart Oldest First")
    func testRowsReadNewestFirstAndTheChartOldestFirst() async throws {
        let screen = makeScreen(sessions: [
            benchSession(id: "older", day: 4, sets: [AnalyticsExerciseFixture.set(id: "a", reps: 1, weightKg: 100)]),
            benchSession(id: "newer", day: 11, sets: [AnalyticsExerciseFixture.set(id: "b", reps: 1, weightKg: 110)])
        ])

        await screen.presenter.loadData()
        let series = try #require(screen.presenter.timeSeries.first)

        #expect(screen.presenter.entries.map(\.oneRMKg) == [110, 100])
        #expect(series.data.map(\.date) == series.data.map(\.date).sorted())
    }

    /// The chart is plotted in the same unit the rows and the axis are labelled with. Plotting
    /// kilograms under a pounds axis puts a 100kg bench on the chart as 100 lb.
    @Test("Test The Chart Is Plotted In The Exercises Unit")
    func testTheChartIsPlottedInTheExercisesUnit() async throws {
        let screen = makeScreen(
            sessions: [benchSession(id: "s", day: 4, sets: [AnalyticsExerciseFixture.set(id: "a", reps: 1, weightKg: 100)])],
            unit: .pounds
        )

        await screen.presenter.loadData()
        let point = try #require(screen.presenter.timeSeries.first?.data.first)
        let row = try #require(screen.presenter.entries.first)

        #expect(abs(point.value - 220.462) < 0.01)
        #expect(screen.presenter.displayValue(for: row) == "220.5")
        #expect(screen.presenter.configuration.yAxisSuffix == " lbs")
    }

    @Test("Test A Kilogram Exercise Plots Stored Kilograms")
    func testAKilogramExercisePlotsStoredKilograms() async throws {
        let screen = makeScreen(sessions: [
            benchSession(id: "s", day: 4, sets: [AnalyticsExerciseFixture.set(id: "a", reps: 1, weightKg: 100)])
        ])

        await screen.presenter.loadData()

        #expect(try #require(screen.presenter.timeSeries.first?.data.first).value == 100)
        #expect(screen.presenter.configuration.yAxisSuffix == " kg")
    }

    /// The screen names the exercise it is showing.
    @Test("Test The Screen Is Titled For Its Exercise")
    func testTheScreenIsTitledForItsExercise() {
        let screen = makeScreen()

        #expect(screen.presenter.configuration.title == "Bench Press")
        #expect(screen.presenter.configuration.emptyStateMessage == "No 1-RM data for Bench Press")
        #expect(screen.presenter.contributionSeries == nil)
    }

    /// A one-rep max is estimated from logged sets, so the way to add one is to train.
    @Test("Test Adding Opens The Workouts List")
    func testAddingOpensTheWorkoutsList() {
        let screen = makeScreen()

        screen.presenter.onAddPressed()

        #expect(screen.router.didShowWorkouts)
        #expect(screen.presenter.configuration.addActionTitle == "Start Workout")
    }
}

/// The Muscle Groups screen: how many sets each muscle got.
@MainActor
struct AnalyticsMuscleGroupsPresenterTests {

    private final class Interactor: SpyGlobalInteractor, MuscleGroupsInteractor {
        var auth: UserAuthInfo?
        var workoutSessions: [WorkoutSessionModel] = []
        var allExercises: [ExerciseModel] = []
    }

    private final class Router: MuscleGroupsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var openedMuscles: [Muscles] = []

        func showMuscleGroupDetailView(muscle: Muscles, delegate: MuscleGroupDetailDelegate, themeColor: Color?) {
            openedMuscles.append(muscle)
        }

        func showMuscleBalanceView() { }
    }

    private struct Screen {
        let presenter: MuscleGroupsPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(sessions: [WorkoutSessionModel] = [], exercises: [ExerciseModel] = []) -> Screen {
        let interactor = Interactor()
        interactor.workoutSessions = sessions
        interactor.allExercises = exercises
        let router = Router()
        return Screen(
            presenter: MuscleGroupsPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func benchSession(id: String, day: Int, sets: [WorkoutSetModel], ended: Bool = true) -> WorkoutSessionModel {
        AnalyticsExerciseFixture.session(id: id, day: day, ended: ended, exercises: [
            AnalyticsExerciseFixture.LoggedExercise(templateId: "bench", sets: sets)
        ])
    }

    private var benchTemplate: ExerciseModel {
        AnalyticsExerciseFixture.exercise(id: "bench", muscles: [.chest: .primary, .triceps: .secondary])
    }

    /// A muscle worked as a secondary counts half a set. Counting it whole would tell a user their
    /// triceps get as much direct work as their chest.
    @Test("Test A Secondary Muscle Counts Half A Set")
    func testASecondaryMuscleCountsHalfASet() {
        let screen = makeScreen(
            sessions: [benchSession(id: "s", day: 4, sets: [
                AnalyticsExerciseFixture.set(id: "a"),
                AnalyticsExerciseFixture.set(id: "b")
            ])],
            exercises: [benchTemplate]
        )

        screen.presenter.loadData()

        #expect(screen.presenter.setsData(for: .chest).total == 2)
        #expect(screen.presenter.setsData(for: .triceps).total == 1)
    }

    /// Only finished working sets count: a warm-up and a set never ticked off are not volume.
    @Test("Test Warm Ups And Unfinished Sets Do Not Count")
    func testWarmUpsAndUnfinishedSetsDoNotCount() {
        let screen = makeScreen(
            sessions: [benchSession(id: "s", day: 4, sets: [
                AnalyticsExerciseFixture.set(id: "warm", isWarmup: true),
                AnalyticsExerciseFixture.set(id: "skipped", completed: false),
                AnalyticsExerciseFixture.set(id: "done")
            ])],
            exercises: [benchTemplate]
        )

        screen.presenter.loadData()

        #expect(screen.presenter.setsData(for: .chest).total == 1)
    }

    /// A workout still in progress has not trained anything yet.
    @Test("Test A Workout In Progress Does Not Count")
    func testAWorkoutInProgressDoesNotCount() {
        let screen = makeScreen(
            sessions: [benchSession(id: "live", day: 4, sets: [AnalyticsExerciseFixture.set(id: "a")], ended: false)],
            exercises: [benchTemplate]
        )

        screen.presenter.loadData()

        #expect(screen.presenter.setsData(for: .chest).total == 0)
    }

    /// Without the exercise template there is no way to know what a set trained, so it is counted
    /// against nothing rather than guessed at.
    @Test("Test A Set Without Its Template Trains Nothing")
    func testASetWithoutItsTemplateTrainsNothing() {
        let screen = makeScreen(
            sessions: [benchSession(id: "s", day: 4, sets: [AnalyticsExerciseFixture.set(id: "a")])],
            exercises: []
        )

        screen.presenter.loadData()

        #expect(screen.presenter.setsData(for: .chest).total == 0)
    }

    /// A muscle nobody has trained reads as a flat week of zeroes rather than as missing data.
    @Test("Test An Untrained Muscle Reads As A Flat Week")
    func testAnUntrainedMuscleReadsAsAFlatWeek() {
        let screen = makeScreen()

        screen.presenter.loadData()

        let data = screen.presenter.setsData(for: .chest)
        #expect(data.last7Days == Array(repeating: 0, count: 7))
        #expect(data.total == 0)
    }

    /// The week is the seven days ending today, so a session from months ago counts toward the
    /// total without shading a day of this week.
    @Test("Test An Old Session Counts In The Total But Not This Week")
    func testAnOldSessionCountsInTheTotalButNotThisWeek() {
        let screen = makeScreen(
            sessions: [benchSession(id: "s", day: 4, sets: [AnalyticsExerciseFixture.set(id: "a")])],
            exercises: [benchTemplate]
        )

        screen.presenter.loadData()

        let data = screen.presenter.setsData(for: .chest)
        #expect(data.total == 1)
        #expect(data.last7Days == Array(repeating: 0, count: 7))
    }

    /// Every muscle belongs to exactly one of the two sections, so none is listed twice or left
    /// off the screen.
    @Test("Test Every Muscle Is In Exactly One Section")
    func testEveryMuscleIsInExactlyOneSection() {
        let screen = makeScreen()

        let listed = screen.presenter.upperMuscles + screen.presenter.lowerMuscles

        #expect(Set(listed).count == listed.count)
        #expect(Set(listed) == Set(Muscles.allCases))
    }

    @Test("Test A Muscle Opens Its Own Detail")
    func testAMuscleOpensItsOwnDetail() {
        let screen = makeScreen()

        screen.presenter.onMusclePressed(muscle: .lats, themeColor: nil)

        #expect(screen.router.openedMuscles == [.lats])
    }

    @Test("Test Appearing Is Tracked")
    func testAppearingIsTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["MuscleGroupsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["MuscleGroupsView_Disappear"])
    }
}
