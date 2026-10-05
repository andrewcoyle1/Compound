//
//  ProgressCarouselMetricsTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The sums behind the Progress tab's header carousel.
@MainActor
struct ProgressCarouselMetricsTests {

    private func set(reps: Int? = 5, weightKg: Double? = 100, side: SetSide? = nil, isWarmup: Bool = false, completed: Bool = true) -> WorkoutSetModel {
        WorkoutSetModel(
            id: UUID().uuidString,
            authorId: "friend",
            index: 1,
            reps: reps,
            weightKg: weightKg,
            side: side,
            isWarmup: isWarmup,
            completedAt: completed ? DashboardFixture.date(day: 2) : nil,
            dateCreated: DashboardFixture.date(day: 2)
        )
    }

    private func exercise(_ name: String, sets: [WorkoutSetModel]) -> WorkoutExerciseModel {
        WorkoutExerciseModel(id: UUID().uuidString, authorId: "friend", templateId: name, name: name, trackingMode: .weightReps, index: 1, sets: sets)
    }

    private func session(_ id: String, day: Int, _ exercises: WorkoutExerciseModel...) -> WorkoutSessionModel {
        DashboardFixture.session(id: id, author: "friend", on: DashboardFixture.date(day: day), finished: true, isRestDay: false, exercises: exercises)
    }

    private func names(_ kind: ProgressCarouselMetrics.RecordKind, _ sessions: [WorkoutSessionModel]) -> [String] {
        ProgressCarouselMetrics.recentRecords(kind, sessions: sessions).map { "\($0.name) \(Int($0.value))" }
    }

    // MARK: - Recent records

    @Test("Test Records Come Most Recently Set First")
    func testRecordsComeMostRecentlySetFirst() {
        let sessions = [
            session("a", day: 2, exercise("Bench", sets: [set(reps: 5, weightKg: 100)]), exercise("Squat", sets: [set(reps: 5, weightKg: 140)])),
            session("b", day: 9, exercise("Squat", sets: [set(reps: 5, weightKg: 150)]))
        ]

        #expect(names(.oneRepMax, sessions) == ["Squat 175", "Bench 116"])
    }

    /// Matching a record later does not move it up the list: it was set on the first day.
    @Test("Test A Matched Record Keeps Its Date")
    func testAMatchedRecordKeepsItsDate() {
        let sessions = [
            session("a", day: 2, exercise("Bench", sets: [set(reps: 12)])),
            session("b", day: 5, exercise("Curl", sets: [set(reps: 10)])),
            session("c", day: 9, exercise("Bench", sets: [set(reps: 12)]))
        ]

        #expect(names(.reps, sessions) == ["Curl 10", "Bench 12"])
    }

    /// Warm-ups and unfinished sets are not records; a combined per-side row counts both sides.
    @Test("Test Volume Counts Finished Working Sets And Both Sides")
    func testVolumeCountsFinishedWorkingSetsAndBothSides() {
        let sessions = [
            session("a", day: 2, exercise("Lunge", sets: [
                set(reps: 10, weightKg: 20, side: .both),
                set(reps: 10, weightKg: 60, isWarmup: true),
                set(reps: 10, weightKg: 60, completed: false)
            ]))
        ]

        #expect(names(.volume, sessions) == ["Lunge 400"])
    }

    // MARK: - Weekly workouts

    @Test("Test Tally Counts A Pair Once And Each Muscle Once")
    func testTallyCountsAPairOnceAndEachMuscleOnce() {
        let sessions = [
            session("a", day: 2,
                    exercise("Row", sets: [set(side: .left), set(side: .right), set(isWarmup: true)]),
                    exercise("Pulldown", sets: [set(), set()]),
                    exercise("Skipped", sets: [set(completed: false)]))
        ]
        let exercises = [
            "Row": exerciseModel("Row", [.upperBack: .primary, .biceps: .secondary]),
            "Pulldown": exerciseModel("Pulldown", [.lats: .primary, .biceps: .secondary])
        ]

        let tally = ProgressCarouselMetrics.tally(sessions: sessions, exercises: exercises)

        #expect(tally == .init(muscles: 3, sets: 3, exercises: 2))
    }

    private func exerciseModel(_ id: String, _ muscles: [Muscles: MuscleTargetType]) -> ExerciseModel {
        ExerciseModel(
            id: id,
            authorId: "friend",
            name: id,
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

    // MARK: - Energy balance

    /// A day with nothing logged is left out, rather than averaged in as a day of eating nothing.
    @Test("Test Averages Skip Unlogged Days")
    func testAveragesSkipUnloggedDays() {
        let days = [
            ProgressCarouselMetrics.EnergyDay(date: DashboardFixture.date(day: 1), intake: 2000, expenditure: 2500, target: 2200),
            ProgressCarouselMetrics.EnergyDay(date: DashboardFixture.date(day: 2), intake: 0, expenditure: 3000, target: 2200),
            ProgressCarouselMetrics.EnergyDay(date: DashboardFixture.date(day: 3), intake: 2400, expenditure: 2700, target: nil)
        ]

        let expenditure = ProgressCarouselMetrics.averages(days) { $0.expenditure }
        let targets = ProgressCarouselMetrics.averages(days) { $0.target }

        #expect(expenditure?.intake == 2200)
        #expect(expenditure?.comparison == 2600)
        #expect(targets?.comparison == 2200)
        #expect(ProgressCarouselMetrics.averages([days[1]]) { $0.expenditure } == nil)
    }
}
