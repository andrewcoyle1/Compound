//
//  MuscleBalanceTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// Muscle Balance: weekly working sets per muscle against a recommended range.
///
/// What is pinned is the weighting (a muscle an exercise only assists earns half a set, a left and
/// right pair is one set), which week a session lands in, and where the range boundaries fall.
@MainActor
struct MuscleBalanceTests {

    private final class Interactor: SpyGlobalInteractor, MuscleBalanceInteractor {
        var workoutSessions: [WorkoutSessionModel] = []
        var allExercises: [ExerciseModel] = []
    }

    private final class Router: MuscleBalanceRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private typealias Fixture = AnalyticsExerciseFixture

    /// Day 31 of the fixture month; sessions are placed by day of that month.
    private let endDate = Fixture.date(day: 31)
    private let calendar = Calendar.current

    private var bench: ExerciseModel {
        Fixture.exercise(id: "bench", muscles: [.chest: .primary, .triceps: .secondary])
    }

    private func benchSession(id: String, day: Int, sets: Int, ended: Bool = true) -> WorkoutSessionModel {
        Fixture.session(id: id, day: day, ended: ended, exercises: [
            Fixture.LoggedExercise(templateId: "bench", sets: (0..<sets).map { Fixture.set(id: "\(id)-\($0)") })
        ])
    }

    private func weekly(_ sessions: [WorkoutSessionModel]) -> [Muscles: [Double]] {
        MuscleVolume.weeklySets(
            sessions: sessions,
            templates: ["bench": bench],
            calendar: calendar,
            endDate: endDate
        )
    }

    // MARK: - Weighting

    @Test("Test A Secondary Muscle Earns Half A Set")
    func testASecondaryMuscleEarnsHalfASet() {
        let result = weekly([benchSession(id: "s", day: 30, sets: 3)])

        #expect(result[.chest]?.last == 3)
        #expect(result[.triceps]?.last == 1.5)
        #expect(result[.quads]?.last == 0)
    }

    @Test("Test A Left And Right Pair Is One Set")
    func testALeftAndRightPairIsOneSet() {
        let sides: [SetSide] = [.left, .right]
        let pair = sides.enumerated().map { offset, side in
            WorkoutSetModel(
                id: "p\(offset)", authorId: "author-1", index: 1, reps: 8, side: side,
                isWarmup: false, completedAt: endDate, dateCreated: endDate
            )
        }
        let session = Fixture.session(id: "s", day: 30, exercises: [Fixture.LoggedExercise(templateId: "bench", sets: pair)])

        #expect(weekly([session])[.chest]?.last == 1)
    }

    @Test("Test Warm Ups And Unfinished Sets Are Not Volume")
    func testWarmUpsAndUnfinishedSetsAreNotVolume() {
        let session = Fixture.session(id: "s", day: 30, exercises: [
            Fixture.LoggedExercise(templateId: "bench", sets: [
                Fixture.set(id: "warm", isWarmup: true),
                Fixture.set(id: "skipped", completed: false),
                Fixture.set(id: "done")
            ])
        ])

        #expect(weekly([session])[.chest]?.last == 1)
    }

    // MARK: - Weeks

    /// Twelve rolling seven-day windows, oldest first. Day 25 is the first day of the current
    /// window (31 − 6), day 24 the last of the one before, and a session twelve weeks back or more
    /// is out of range.
    @Test("Test Sessions Land In Their Rolling Week")
    func testSessionsLandInTheirRollingWeek() {
        let sessions = [
            benchSession(id: "today", day: 31, sets: 1),
            benchSession(id: "edge", day: 25, sets: 2),
            benchSession(id: "previous", day: 24, sets: 4)
        ]

        let chest = weekly(sessions)[.chest] ?? []

        #expect(chest.count == 12)
        #expect(chest[11] == 3)
        #expect(chest[10] == 4)
        #expect(chest.prefix(10).allSatisfy { $0 == 0 })
    }

    @Test("Test Sessions Outside The Twelve Weeks Are Ignored")
    func testSessionsOutsideTheTwelveWeeksAreIgnored() {
        let old = Fixture.session(id: "old", day: 1, exercises: [
            Fixture.LoggedExercise(templateId: "bench", sets: [Fixture.set(id: "a")])
        ])
        let oldDate = calendar.date(byAdding: .day, value: -84, to: endDate) ?? endDate
        let tooOld = WorkoutSessionModel(
            id: "too-old", authorId: "author-1", name: "Old", dateCreated: oldDate, endedAt: oldDate,
            exercises: old.exercises, isRestDay: false
        )
        let future = WorkoutSessionModel(
            id: "future", authorId: "author-1", name: "Future",
            dateCreated: endDate.addingTimeInterval(86_400 * 2), endedAt: endDate.addingTimeInterval(86_400 * 2),
            exercises: old.exercises, isRestDay: false
        )

        let chest = weekly([tooOld, future])[.chest] ?? []

        #expect(chest.allSatisfy { $0 == 0 })
    }

    // MARK: - Range classification

    @Test("Test A Large Muscle Aims For Ten To Twenty Sets", arguments: [
        (9.5, MuscleBalanceStatus.below), (10, .within), (20, .within), (20.5, .above)
    ])
    func testALargeMuscleAimsForTenToTwentySets(sets: Double, expected: MuscleBalanceStatus) {
        #expect(MuscleVolume.recommendedWeeklySets(for: .chest) == 10...20)
        #expect(MuscleVolume.classify(sets: sets, for: .chest) == expected)
    }

    @Test("Test A Small Muscle Aims For Six To Twelve Sets", arguments: [
        (5.5, MuscleBalanceStatus.below), (6, .within), (12, .within), (12.5, .above)
    ])
    func testASmallMuscleAimsForSixToTwelveSets(sets: Double, expected: MuscleBalanceStatus) {
        #expect(MuscleVolume.recommendedWeeklySets(for: .biceps) == 6...12)
        #expect(MuscleVolume.classify(sets: sets, for: .biceps) == expected)
    }

    /// Each status has its own icon and word, so the tile does not rest on colour alone.
    @Test("Test Every Status Has A Distinct Icon And Label")
    func testEveryStatusHasADistinctIconAndLabel() {
        let statuses: [MuscleBalanceStatus] = [.below, .within, .above]
        #expect(Set(statuses.map(\.systemImage)).count == 3)
        #expect(Set(statuses.map(\.label)).count == 3)
    }

    // MARK: - Presenter

    private func makePresenter(sessions: [WorkoutSessionModel]) -> (MuscleBalancePresenter, Interactor) {
        let interactor = Interactor()
        interactor.workoutSessions = sessions
        interactor.allExercises = [bench]
        return (MuscleBalancePresenter(interactor: interactor, router: Router(), calendar: calendar), interactor)
    }

    @Test("Test Every Muscle Gets A Row And Unfinished Sessions Are Left Out")
    func testEveryMuscleGetsARowAndUnfinishedSessionsAreLeftOut() throws {
        let (presenter, _) = makePresenter(sessions: [
            benchSession(id: "done", day: 30, sets: 12),
            benchSession(id: "live", day: 31, sets: 5, ended: false)
        ])

        presenter.loadData(endDate: endDate)

        #expect(presenter.rows.count == Muscles.allCases.count)
        #expect(presenter.upperRows.count + presenter.lowerRows.count == Muscles.allCases.count)
        let chest = try #require(presenter.rows.first { $0.muscle == .chest })
        #expect(chest.currentSets == 12)
        #expect(chest.status == .within)
        let triceps = try #require(presenter.rows.first { $0.muscle == .triceps })
        #expect(triceps.status == .within)
        let quads = try #require(presenter.rows.first { $0.muscle == .quads })
        #expect(quads.status == .below)
    }

    @Test("Test Tapping A Muscle Toggles Its Trend")
    func testTappingAMuscleTogglesItsTrend() {
        let (presenter, interactor) = makePresenter(sessions: [])
        presenter.loadData(endDate: endDate)

        presenter.onMusclePressed(.chest)
        #expect(presenter.selectedRow?.muscle == .chest)

        presenter.onMusclePressed(.biceps)
        #expect(presenter.selectedRow?.muscle == .biceps)

        presenter.onMusclePressed(.biceps)
        #expect(presenter.selectedRow == nil)
        #expect(interactor.trackedEventNames.filter { $0 == "MuscleBalanceView_Muscle_Press" }.count == 3)
    }

    @Test("Test The Sparkline Has Twelve Weekly Points Ending Today")
    func testTheSparklineHasTwelveWeeklyPointsEndingToday() throws {
        let (presenter, _) = makePresenter(sessions: [benchSession(id: "s", day: 30, sets: 3)])
        presenter.loadData(endDate: endDate)
        let chest = try #require(presenter.rows.first { $0.muscle == .chest })

        let points = presenter.sparklineData(for: chest)

        #expect(points.count == 12)
        #expect(points.last?.date == calendar.startOfDay(for: endDate))
        #expect(points.last?.value == 3)
        #expect(points.first?.date == calendar.date(byAdding: .day, value: -77, to: calendar.startOfDay(for: endDate)))
    }
}
