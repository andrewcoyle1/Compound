//
//  MuscleGroupDetailPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// How many sets a muscle got, per day.
///
/// The rule worth pinning is the weighting: a muscle worked as a secondary counts half a set. A
/// bench press trains the chest directly and the triceps along the way, and counting both as whole
/// sets would tell a user their triceps get as much work as their chest.
///
/// The count is of *completed* working sets, so a session someone planned but did not finish does
/// not inflate their weekly volume.
@MainActor
struct MuscleGroupDetailPresenterTests {

    private final class Interactor: SpyGlobalInteractor, MuscleGroupDetailInteractor {
        var auth: UserAuthInfo?
        var workoutSessions: [WorkoutSessionModel] = []
        var allExercises: [ExerciseModel] = []
    }

    private final class Router: MuscleGroupDetailRouter {
        let router: AnyRouter = TestRouting.anyRouter

        func showWorkoutsView(delegate: WorkoutsDelegate) { }
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func exercise(id: String, muscles: [Muscles: MuscleTargetType]) -> ExerciseModel {
        ExerciseModel(
            id: id,
            authorId: "author-1",
            name: "Bench Press",
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

    private func set(index: Int, isWarmup: Bool = false, completed: Bool = true) -> WorkoutSetModel {
        WorkoutSetModel(
            id: "set-\(index)-\(isWarmup)-\(completed)",
            authorId: "author-1",
            index: index,
            reps: 8,
            weightKg: 80,
            isWarmup: isWarmup,
            completedAt: completed ? start : nil,
            dateCreated: start
        )
    }

    private func session(
        id: String,
        daysAgo: Int = 0,
        ended: Bool = true,
        templateId: String = "exercise-1",
        sets: [WorkoutSetModel]
    ) -> WorkoutSessionModel {
        let date = start.addingTimeInterval(Double(-daysAgo) * 86400)
        return WorkoutSessionModel(
            id: id,
            authorId: "author-1",
            name: "Push Day",
            dateCreated: date,
            endedAt: ended ? date.addingTimeInterval(3600) : nil,
            exercises: [
                WorkoutExerciseModel(
                    id: "we-\(id)",
                    authorId: "author-1",
                    templateId: templateId,
                    name: "Bench Press",
                    trackingMode: .weightReps,
                    index: 1,
                    sets: sets
                )
            ]
        )
    }

    private func makePresenter(
        muscle: Muscles = .chest,
        sessions: [WorkoutSessionModel],
        exercises: [ExerciseModel]
    ) -> MuscleGroupDetailPresenter {
        let interactor = Interactor()
        interactor.workoutSessions = sessions
        interactor.allExercises = exercises
        return MuscleGroupDetailPresenter(interactor: interactor, router: Router(), muscle: muscle)
    }

    // MARK: - Weighting

    @Test("Test A Primary Muscle Counts A Whole Set")
    func testAPrimaryMuscleCountsAWholeSet() async throws {
        let presenter = makePresenter(
            muscle: .chest,
            sessions: [session(id: "s1", sets: [set(index: 1), set(index: 2)])],
            exercises: [exercise(id: "exercise-1", muscles: [.chest: .primary, .triceps: .secondary])]
        )

        await presenter.loadData()

        #expect(try #require(presenter.entries.first).sets == 2)
    }

    /// The rule this screen exists to get right.
    @Test("Test A Secondary Muscle Counts Half A Set")
    func testASecondaryMuscleCountsHalfASet() async throws {
        let presenter = makePresenter(
            muscle: .triceps,
            sessions: [session(id: "s1", sets: [set(index: 1), set(index: 2)])],
            exercises: [exercise(id: "exercise-1", muscles: [.chest: .primary, .triceps: .secondary])]
        )

        await presenter.loadData()

        #expect(try #require(presenter.entries.first).sets == 1)
    }

    @Test("Test A Muscle The Exercise Does Not Work Counts Nothing")
    func testAMuscleTheExerciseDoesNotWorkCountsNothing() async {
        let presenter = makePresenter(
            muscle: .quads,
            sessions: [session(id: "s1", sets: [set(index: 1)])],
            exercises: [exercise(id: "exercise-1", muscles: [.chest: .primary])]
        )

        await presenter.loadData()

        #expect(presenter.entries.isEmpty)
    }

    // MARK: - Which sets count

    /// A unilateral set is logged as a left and a right row, but it is one set of work. This chart
    /// used to count both rows while the Muscle Groups cards counted one, so the two disagreed.
    @Test("Test A Left And Right Pair Counts As One Set")
    func testALeftAndRightPairCountsAsOneSet() async throws {
        let sides: [SetSide] = [.left, .right]
        let pair = sides.enumerated().map { offset, side in
            WorkoutSetModel(
                id: "pair-\(offset)",
                authorId: "author-1",
                index: 1,
                reps: 8,
                side: side,
                isWarmup: false,
                completedAt: start,
                dateCreated: start
            )
        }
        let presenter = makePresenter(
            sessions: [session(id: "s1", sets: pair)],
            exercises: [exercise(id: "exercise-1", muscles: [.chest: .primary])]
        )

        await presenter.loadData()

        #expect(try #require(presenter.entries.first).sets == 1)
    }

    /// A set that was planned but never done is not work performed.
    @Test("Test Unfinished Sets Are Not Counted")
    func testUnfinishedSetsAreNotCounted() async throws {
        let presenter = makePresenter(
            sessions: [session(id: "s1", sets: [
                set(index: 1, completed: true),
                set(index: 2, completed: false)
            ])],
            exercises: [exercise(id: "exercise-1", muscles: [.chest: .primary])]
        )

        await presenter.loadData()

        #expect(try #require(presenter.entries.first).sets == 1)
    }

    @Test("Test Warm-Up Sets Are Not Counted")
    func testWarmUpSetsAreNotCounted() async throws {
        let presenter = makePresenter(
            sessions: [session(id: "s1", sets: [
                set(index: 1, isWarmup: true),
                set(index: 2)
            ])],
            exercises: [exercise(id: "exercise-1", muscles: [.chest: .primary])]
        )

        await presenter.loadData()

        #expect(try #require(presenter.entries.first).sets == 1)
    }

    @Test("Test Unfinished Sessions Are Left Out")
    func testUnfinishedSessionsAreLeftOut() async {
        let presenter = makePresenter(
            sessions: [session(id: "live", ended: false, sets: [set(index: 1)])],
            exercises: [exercise(id: "exercise-1", muscles: [.chest: .primary])]
        )

        await presenter.loadData()

        #expect(presenter.entries.isEmpty)
    }

    /// An exercise the library no longer holds cannot say which muscles it worked, so it is skipped
    /// rather than counted against an arbitrary one.
    @Test("Test An Unknown Exercise Is Skipped")
    func testAnUnknownExerciseIsSkipped() async {
        let presenter = makePresenter(
            sessions: [session(id: "s1", templateId: "missing", sets: [set(index: 1)])],
            exercises: [exercise(id: "exercise-1", muscles: [.chest: .primary])]
        )

        await presenter.loadData()

        #expect(presenter.entries.isEmpty)
    }

    // MARK: - Grouping by day

    @Test("Test Sessions On The Same Day Add Together")
    func testSessionsOnTheSameDayAddTogether() async throws {
        let presenter = makePresenter(
            sessions: [
                session(id: "morning", daysAgo: 1, sets: [set(index: 1)]),
                session(id: "evening", daysAgo: 1, sets: [set(index: 2), set(index: 3)])
            ],
            exercises: [exercise(id: "exercise-1", muscles: [.chest: .primary])]
        )

        await presenter.loadData()

        #expect(presenter.entries.count == 1)
        #expect(try #require(presenter.entries.first).sets == 3)
    }

    @Test("Test Separate Days Stay Separate")
    func testSeparateDaysStaySeparate() async {
        let presenter = makePresenter(
            sessions: [
                session(id: "s1", daysAgo: 2, sets: [set(index: 1)]),
                session(id: "s2", daysAgo: 1, sets: [set(index: 2)])
            ],
            exercises: [exercise(id: "exercise-1", muscles: [.chest: .primary])]
        )

        await presenter.loadData()

        #expect(presenter.entries.count == 2)
    }

    @Test("Test The List Reads Newest First And The Chart Oldest First")
    func testTheListReadsNewestFirstAndTheChartOldestFirst() async throws {
        let presenter = makePresenter(
            sessions: [
                session(id: "s1", daysAgo: 3, sets: [set(index: 1)]),
                session(id: "s2", daysAgo: 1, sets: [set(index: 2)])
            ],
            exercises: [exercise(id: "exercise-1", muscles: [.chest: .primary])]
        )

        await presenter.loadData()

        let listDates = presenter.entries.map(\.date)
        let chartDates = try #require(presenter.timeSeries.first).data.map(\.date)

        #expect(listDates == listDates.sorted(by: >))
        #expect(chartDates == chartDates.sorted())
    }

    @Test("Test Nothing Trained Leaves The Screen Empty")
    func testNothingTrainedLeavesTheScreenEmpty() async {
        let presenter = makePresenter(sessions: [], exercises: [])

        await presenter.loadData()

        #expect(presenter.entries.isEmpty)
        #expect(presenter.timeSeries.first?.data.isEmpty == true)
    }
}
