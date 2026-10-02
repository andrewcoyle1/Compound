//
//  WorkoutPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The Workouts screen: every finished session, with the sets and volume it accounted for.
///
/// Volume is weight times reps, summed across the working sets. Warm-ups are excluded from both
/// figures, which is the rule that matters: counting them would inflate every session by however
/// thorough the user's warm-up was, and reward a longer ramp as if it were more training.
@MainActor
struct WorkoutPresenterTests {

    private final class Interactor: SpyGlobalInteractor, WorkoutInteractor {
        var auth: UserAuthInfo?
        var workoutSessions: [WorkoutSessionModel] = []
    }

    private final class Router: WorkoutRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var didShowWorkouts = false

        func showWorkoutsView(delegate: WorkoutsDelegate) {
            didShowWorkouts = true
        }
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(index: Int, reps: Int?, weightKg: Double?, isWarmup: Bool = false) -> WorkoutSetModel {
        WorkoutSetModel(
            id: "set-\(index)-\(isWarmup)",
            authorId: "author-1",
            index: index,
            reps: reps,
            weightKg: weightKg,
            isWarmup: isWarmup,
            dateCreated: start
        )
    }

    private func session(
        id: String,
        name: String = "Push Day",
        daysAgo: Int = 0,
        ended: Bool = true,
        sets: [WorkoutSetModel] = []
    ) -> WorkoutSessionModel {
        let date = start.addingTimeInterval(Double(-daysAgo) * 86400)
        return WorkoutSessionModel(
            id: id,
            authorId: "author-1",
            name: name,
            dateCreated: date,
            endedAt: ended ? date.addingTimeInterval(3600) : nil,
            exercises: sets.isEmpty ? [] : [
                WorkoutExerciseModel(
                    id: "exercise-1",
                    authorId: "author-1",
                    templateId: "template-1",
                    name: "Bench Press",
                    trackingMode: .weightReps,
                    index: 1,
                    sets: sets
                )
            ]
        )
    }

    private func makePresenter(_ sessions: [WorkoutSessionModel]) -> WorkoutPresenter {
        let interactor = Interactor()
        interactor.workoutSessions = sessions
        return WorkoutPresenter(interactor: interactor, router: Router())
    }

    // MARK: - Which sessions count

    /// A workout still in progress is not history.
    @Test("Test Unfinished Sessions Are Left Out")
    func testUnfinishedSessionsAreLeftOut() {
        let presenter = makePresenter([
            session(id: "done", daysAgo: 1),
            session(id: "live", daysAgo: 0, ended: false)
        ])

        #expect(presenter.entries.map(\.id) == ["done"])
    }

    @Test("Test No Sessions Leave The Screen Empty")
    func testNoSessionsLeaveTheScreenEmpty() {
        let presenter = makePresenter([])

        #expect(presenter.entries.isEmpty)
        #expect(presenter.timeSeries.first?.data.isEmpty == true)
    }

    // MARK: - Counting sets

    /// Warm-ups are not training volume. Counting them would make a session look bigger for being
    /// more cautious.
    @Test("Test Warm-Up Sets Are Not Counted")
    func testWarmUpSetsAreNotCounted() throws {
        let presenter = makePresenter([
            session(id: "s1", sets: [
                set(index: 1, reps: 10, weightKg: 40, isWarmup: true),
                set(index: 2, reps: 8, weightKg: 80),
                set(index: 3, reps: 8, weightKg: 80)
            ])
        ])

        #expect(try #require(presenter.entries.first).sets == 2)
    }

    @Test("Test A Session Of Only Warm-Ups Counts Nothing")
    func testASessionOfOnlyWarmUpsCountsNothing() throws {
        let presenter = makePresenter([
            session(id: "s1", sets: [set(index: 1, reps: 10, weightKg: 40, isWarmup: true)])
        ])

        let entry = try #require(presenter.entries.first)
        #expect(entry.sets == 0)
        #expect(entry.volumeKg == 0)
    }

    // MARK: - Volume

    @Test("Test Volume Is Weight Times Reps Across The Working Sets")
    func testVolumeIsWeightTimesRepsAcrossTheWorkingSets() throws {
        let presenter = makePresenter([
            session(id: "s1", sets: [
                set(index: 1, reps: 8, weightKg: 80),
                set(index: 2, reps: 6, weightKg: 90)
            ])
        ])

        // 640 + 540
        #expect(try #require(presenter.entries.first).volumeKg == 1180)
    }

    @Test("Test Warm-Up Volume Is Excluded")
    func testWarmUpVolumeIsExcluded() throws {
        let presenter = makePresenter([
            session(id: "s1", sets: [
                set(index: 1, reps: 20, weightKg: 20, isWarmup: true),
                set(index: 2, reps: 8, weightKg: 80)
            ])
        ])

        #expect(try #require(presenter.entries.first).volumeKg == 640)
    }

    /// Bodyweight and timed work carry no weight or no reps, so they contribute sets but no volume
    /// rather than counting as zero-weight lifts or crashing the sum.
    @Test("Test Sets Without Weight Or Reps Add No Volume")
    func testSetsWithoutWeightOrRepsAddNoVolume() throws {
        let presenter = makePresenter([
            session(id: "s1", sets: [
                set(index: 1, reps: 12, weightKg: nil),
                set(index: 2, reps: nil, weightKg: 80),
                set(index: 3, reps: 8, weightKg: 80)
            ])
        ])

        let entry = try #require(presenter.entries.first)
        #expect(entry.sets == 3)
        #expect(entry.volumeKg == 640)
    }

    // MARK: - Order and dating

    /// The list reads newest first; the chart plots forwards in time.
    @Test("Test The List Reads Newest First And The Chart Oldest First")
    func testTheListReadsNewestFirstAndTheChartOldestFirst() throws {
        let presenter = makePresenter([
            session(id: "s2", daysAgo: 2),
            session(id: "s1", daysAgo: 5),
            session(id: "s3", daysAgo: 1)
        ])

        #expect(presenter.entries.map(\.id) == ["s3", "s2", "s1"])
        let chartDates = try #require(presenter.timeSeries.first).data.map(\.date)
        #expect(chartDates == chartDates.sorted())
    }

    /// A session is dated by when it finished, not when it started, so a workout begun before
    /// midnight lands on the day it was completed.
    @Test("Test A Session Is Dated By When It Finished")
    func testASessionIsDatedByWhenItFinished() throws {
        let presenter = makePresenter([session(id: "s1", daysAgo: 0)])

        let entry = try #require(presenter.entries.first)
        #expect(entry.date == start.addingTimeInterval(3600))
    }

    @Test("Test An Entry Keeps The Workout's Name")
    func testAnEntryKeepsTheWorkoutsName() throws {
        let presenter = makePresenter([session(id: "s1", name: "Leg Day")])

        #expect(try #require(presenter.entries.first).name == "Leg Day")
    }

    // MARK: - The chart

    @Test("Test The Chart Plots Sets Per Session")
    func testTheChartPlotsSetsPerSession() throws {
        let presenter = makePresenter([
            session(id: "s1", daysAgo: 2, sets: [set(index: 1, reps: 8, weightKg: 80)]),
            session(id: "s2", daysAgo: 1, sets: [
                set(index: 1, reps: 8, weightKg: 80),
                set(index: 2, reps: 8, weightKg: 80)
            ])
        ])

        let series = try #require(presenter.timeSeries.first)
        #expect(series.name == "Sets")
        #expect(series.data.map(\.value) == [1, 2])
    }
}
