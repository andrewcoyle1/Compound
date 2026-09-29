//
//  ExerciseModelDetailPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// One exercise from the library, opened to read its history.
///
/// Everything on the screen — the history list, the two charts and the records — is derived from
/// the finished sessions that happened to include this exercise, walked once when the screen
/// appears. Warm-up sets and sets never marked done are left out, as they are everywhere else:
/// counting a ramp-up as training would inflate every figure on the screen.
///
/// Sessions are stored in kilograms whatever the user logs in, so the other half of this screen is
/// converting them back into the unit that exercise is logged in before anything is shown.
@MainActor
struct ExerciseModelDetailPresenterTests {

    private final class Interactor: ExerciseModelDetailInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var workoutSessions: [WorkoutSessionModel] = []
        var preferences: [String: ExerciseUnitPreference] = [:]
        private(set) var preferenceReads: [String] = []

        func getPreference(templateId: String) -> ExerciseUnitPreference {
            preferenceReads.append(templateId)
            return preferences[templateId] ?? ExerciseUnitPreference(exerciseModelId: templateId)
        }

        func deleteExerciseModel(exerciseId: String) async throws { }
    }

    /// Declared unguarded: the test target builds without `-DDEV`, so guarding it the way the
    /// router does would leave nothing here in some configurations and a missing requirement in
    /// others.
    private final class Router: ExerciseModelDetailRouter {
        let router: AnyRouter = TestRouting.anyRouter

        func showDevSettingsView() { }
    }

    private struct Screen {
        let presenter: ExerciseModelDetailPresenter
        let interactor: Interactor
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func day(_ offset: Int) -> Date {
        start.addingTimeInterval(TimeInterval(offset) * 86_400)
    }

    private func exerciseModel(id: String = "bench") -> ExerciseModel {
        ExerciseModel(
            id: id,
            authorId: "user-1",
            name: "Bench Press",
            trackableMetrics: [.weight, .reps],
            type: .compoundUpper,
            laterality: .bilateral,
            muscleGroups: [:],
            isBodyweight: false,
            rangeOfMotion: 1,
            stability: 1,
            bodyWeightContribution: 0,
            alternateNames: []
        )
    }

    private func set(
        _ index: Int,
        reps: Int? = 5,
        weightKg: Double? = 100,
        isWarmup: Bool = false,
        completed: Bool = true
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: "set-\(index)-\(UUID().uuidString)",
            authorId: "user-1",
            index: index,
            reps: reps,
            weightKg: weightKg,
            isWarmup: isWarmup,
            completedAt: completed ? start : nil,
            dateCreated: start
        )
    }

    private func session(
        id: String,
        on date: Date,
        templateId: String = "bench",
        sets: [WorkoutSetModel],
        finished: Bool = true
    ) -> WorkoutSessionModel {
        WorkoutSessionModel(
            id: id,
            authorId: "user-1",
            name: "Push Day",
            dateCreated: date,
            endedAt: finished ? date : nil,
            exercises: [
                WorkoutExerciseModel(
                    id: "exercise-\(id)",
                    authorId: "user-1",
                    templateId: templateId,
                    name: "Bench Press",
                    trackingMode: .weightReps,
                    index: 1,
                    sets: sets
                )
            ]
        )
    }

    private func makeScreen(
        sessions: [WorkoutSessionModel] = [],
        weightUnit: ExerciseWeightUnit = .kilograms
    ) -> Screen {
        let interactor = Interactor()
        interactor.workoutSessions = sessions
        interactor.preferences["bench"] = ExerciseUnitPreference(exerciseModelId: "bench", weightUnit: weightUnit)
        return Screen(
            presenter: ExerciseModelDetailPresenter(interactor: interactor, router: Router()),
            interactor: interactor
        )
    }

    // MARK: - What counts as history

    /// Nothing is read until the screen appears, so an unopened screen shows no history rather than
    /// somebody else's.
    @Test("Test There Is No History Before The Screen Appears")
    func testThereIsNoHistoryBeforeTheScreenAppears() {
        let screen = makeScreen(sessions: [session(id: "s1", on: day(0), sets: [set(1)])])

        #expect(screen.presenter.stats.isEmpty)
        #expect(screen.presenter.performedSubtitle == "No history yet")
    }

    @Test("Test Sessions With This Exercise Become Its History")
    func testSessionsWithThisExerciseBecomeItsHistory() {
        let screen = makeScreen(sessions: [
            session(id: "s1", on: day(0), sets: [set(1), set(2)]),
            session(id: "s2", on: day(7), sets: [set(1)])
        ])

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.presenter.stats.performances.count == 2)
        #expect(screen.presenter.stats.totalSets == 3)
    }

    /// Another exercise's sets belong to that exercise, however many of them share the session.
    @Test("Test Another Exercises Sets Are Not Counted")
    func testAnotherExercisesSetsAreNotCounted() {
        let screen = makeScreen(sessions: [
            session(id: "s1", on: day(0), templateId: "squat", sets: [set(1), set(2)])
        ])

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.presenter.stats.isEmpty)
    }

    /// A workout still in progress is not history yet — its figures would change under the screen.
    @Test("Test An Unfinished Workout Is Not History Yet")
    func testAnUnfinishedWorkoutIsNotHistoryYet() {
        let screen = makeScreen(sessions: [
            session(id: "s1", on: day(0), sets: [set(1)], finished: false)
        ])

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.presenter.stats.isEmpty)
    }

    /// Warm-ups and sets never marked done are excluded, as they are on the workouts screen —
    /// counting a ramp-up would make a longer warm-up look like more training.
    @Test("Test Warm Ups And Unfinished Sets Are Left Out")
    func testWarmUpsAndUnfinishedSetsAreLeftOut() {
        let screen = makeScreen(sessions: [
            session(id: "s1", on: day(0), sets: [
                set(1, reps: 10, weightKg: 40, isWarmup: true),
                set(2, reps: 5, weightKg: 100),
                set(3, reps: 5, weightKg: 100, completed: false)
            ])
        ])

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.presenter.stats.totalSets == 1)
        #expect(screen.presenter.stats.totalReps == 5)
        #expect(screen.presenter.stats.totalVolumeKg == 500)
    }

    /// A session made entirely of warm-ups is not a performance of the exercise at all, rather than
    /// one with nothing in it.
    @Test("Test A Session Of Only Warm Ups Is Not A Performance")
    func testASessionOfOnlyWarmUpsIsNotAPerformance() {
        let screen = makeScreen(sessions: [
            session(id: "s1", on: day(0), sets: [set(1, isWarmup: true), set(2, isWarmup: true)])
        ])

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.presenter.stats.isEmpty)
    }

    /// The heaviest set ever done is what the screen leads with, taken across every session rather
    /// than from the most recent one.
    @Test("Test The Heaviest Set Is The Heaviest Ever Done")
    func testTheHeaviestSetIsTheHeaviestEverDone() {
        let screen = makeScreen(sessions: [
            session(id: "s1", on: day(0), sets: [set(1, reps: 3, weightKg: 120)]),
            session(id: "s2", on: day(7), sets: [set(1, reps: 8, weightKg: 90)])
        ])

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.presenter.stats.heaviestSetKg == 120)
        #expect(screen.presenter.stats.repsAtHeaviestSet == 3)
        #expect(screen.presenter.stats.heaviestSetDate == day(0))
    }

    /// At the same top weight, more reps is the better set — whichever session or position it came
    /// in. The first set at that weight used to win, so a later 100 × 5 read as 100 × 3.
    @Test("Test At Equal Weight The Set With More Reps Is The Heaviest")
    func testAtEqualWeightTheSetWithMoreRepsIsTheHeaviest() {
        let screen = makeScreen(sessions: [
            session(id: "s1", on: day(0), sets: [set(1, reps: 3, weightKg: 100)]),
            session(id: "s2", on: day(7), sets: [set(1, reps: 4, weightKg: 100), set(2, reps: 5, weightKg: 100)])
        ])

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.presenter.stats.heaviestSetKg == 100)
        #expect(screen.presenter.stats.repsAtHeaviestSet == 5)
        #expect(screen.presenter.stats.heaviestSetDate == day(7))
    }

    // MARK: - The subtitle

    @Test("Test The Subtitle Counts How Many Times And When")
    func testTheSubtitleCountsHowManyTimesAndWhen() {
        let screen = makeScreen(sessions: [
            session(id: "s1", on: day(0), sets: [set(1)]),
            session(id: "s2", on: day(7), sets: [set(1)])
        ])

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.presenter.performedSubtitle.hasPrefix("Performed 2 times · last "))
        #expect(screen.presenter.performedSubtitle.contains(day(7).formatted(date: .abbreviated, time: .omitted)))
    }

    /// One session reads "1 time", not "1 times".
    @Test("Test A Single Performance Reads In The Singular")
    func testASinglePerformanceReadsInTheSingular() {
        let screen = makeScreen(sessions: [session(id: "s1", on: day(0), sets: [set(1)])])

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.presenter.performedSubtitle.hasPrefix("Performed 1 time ·"))
    }

    // MARK: - Units

    /// The exercise's own unit preference is what the screen is drawn in. It is read for the
    /// exercise being shown, not for whatever was open last.
    @Test("Test The Screen Is Drawn In The Exercises Own Unit")
    func testTheScreenIsDrawnInTheExercisesOwnUnit() {
        let screen = makeScreen(weightUnit: .pounds)

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.interactor.preferenceReads == ["bench"])
        #expect(screen.presenter.weightUnit == .pounds)
        #expect(screen.presenter.weightChartConfiguration.unit == "lbs")
    }

    /// A user logging in pounds sees pounds: 100 kg is 220 lb, not 100 lb under a "lbs" label.
    @Test("Test Weights Are Converted Into The Exercises Unit")
    func testWeightsAreConvertedIntoTheExercisesUnit() {
        let screen = makeScreen(
            sessions: [session(id: "s1", on: day(0), sets: [set(1, reps: 5, weightKg: 100)])],
            weightUnit: .pounds
        )

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.presenter.formattedWeight(100) == "220 lbs")
        #expect(screen.presenter.weightSeries.first?.data.first?.value == UnitConversion.kgToLbs(100))
    }

    /// A user logging in kilograms sees the stored figure untouched — converting a kilogram weight
    /// into kilograms twice would be the same mistake in the other direction.
    @Test("Test Kilogram Weights Are Not Converted")
    func testKilogramWeightsAreNotConverted() {
        let screen = makeScreen(
            sessions: [session(id: "s1", on: day(0), sets: [set(1, reps: 5, weightKg: 100)])],
            weightUnit: .kilograms
        )

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.presenter.formattedWeight(100) == "100 kg")
        #expect(screen.presenter.weightSeries.first?.data.first?.value == 100)
    }

    // MARK: - The charts

    /// A point per session rather than per day: the exercise is not trained daily, and a daily
    /// series would be mostly gaps.
    @Test("Test The Weight Chart Has A Point Per Session Oldest First")
    func testTheWeightChartHasAPointPerSessionOldestFirst() {
        let screen = makeScreen(sessions: [
            session(id: "s2", on: day(7), sets: [set(1, weightKg: 110)]),
            session(id: "s1", on: day(0), sets: [set(1, weightKg: 100)])
        ])

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.presenter.weightSeries.first?.data.map(\.value) == [100, 110])
    }

    /// Reps are counted rather than averaged, so the chart adds up a session's sets.
    @Test("Test The Reps Chart Totals Each Sessions Reps")
    func testTheRepsChartTotalsEachSessionsReps() {
        let screen = makeScreen(sessions: [
            session(id: "s1", on: day(0), sets: [set(1, reps: 5), set(2, reps: 8)])
        ])

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.presenter.repsSeries.first?.data.map(\.value) == [13])
        // Counted, not averaged: two sets of a session are one bar of 13 reps.
        if case .sum = screen.presenter.repsChartConfiguration.aggregation {
        } else {
            Issue.record("Reps should be totalled across a session, not averaged")
        }
    }

    // MARK: - Records

    /// A record is a session that beat everything before it, so a heavy day followed by a lighter
    /// one leaves one record, not two.
    @Test("Test Only Sessions That Beat Everything Before Are Records")
    func testOnlySessionsThatBeatEverythingBeforeAreRecords() {
        let screen = makeScreen(sessions: [
            session(id: "s1", on: day(0), sets: [set(1, reps: 5, weightKg: 100)]),
            session(id: "s2", on: day(7), sets: [set(1, reps: 5, weightKg: 90)]),
            session(id: "s3", on: day(14), sets: [set(1, reps: 5, weightKg: 110)])
        ])

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        // Newest first, so the standing record reads at the top.
        #expect(screen.presenter.oneRMRecords.map(\.sessionId) == ["s3", "s1"])
    }

    /// Equalling an earlier best is not a record — otherwise every repeat of the same session would
    /// add another row.
    @Test("Test Equalling A Best Is Not A New Record")
    func testEquallingABestIsNotANewRecord() {
        let screen = makeScreen(sessions: [
            session(id: "s1", on: day(0), sets: [set(1, reps: 5, weightKg: 100)]),
            session(id: "s2", on: day(7), sets: [set(1, reps: 5, weightKg: 100)])
        ])

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.presenter.oneRMRecords.map(\.sessionId) == ["s1"])
    }

    /// More reps at the same weight is a better set, so it counts as a record even though nothing
    /// heavier was lifted.
    @Test("Test More Reps At The Same Weight Is A Record")
    func testMoreRepsAtTheSameWeightIsARecord() {
        let screen = makeScreen(sessions: [
            session(id: "s1", on: day(0), sets: [set(1, reps: 5, weightKg: 100)]),
            session(id: "s2", on: day(7), sets: [set(1, reps: 8, weightKg: 100)])
        ])

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.presenter.oneRMRecords.map(\.sessionId) == ["s2", "s1"])
    }

    // MARK: - The history list

    @Test("Test The History Reads Newest First")
    func testTheHistoryReadsNewestFirst() {
        let screen = makeScreen(sessions: [
            session(id: "s1", on: day(0), sets: [set(1)]),
            session(id: "s3", on: day(14), sets: [set(1)]),
            session(id: "s2", on: day(7), sets: [set(1)])
        ])

        screen.presenter.onViewAppear(delegate: ExerciseModelDetailDelegate(exerciseModel: exerciseModel()))

        #expect(screen.presenter.stats.mostRecentFirst.map(\.sessionId) == ["s3", "s2", "s1"])
    }

    /// The screen opens on the description, which is the only tab that reads without any history.
    @Test("Test The Screen Opens On The Description")
    func testTheScreenOpensOnTheDescription() {
        let screen = makeScreen()

        #expect(screen.presenter.section == .description)
    }
}
