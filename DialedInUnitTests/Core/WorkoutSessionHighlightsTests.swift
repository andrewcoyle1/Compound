//
//  WorkoutSessionHighlightsTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

/// The feed card's highlights: which lifts were records, and where the session sits in its week.
///
/// Kept out of `DashboardSocialPresenterTests.swift`, which is at the file-length limit; the
/// presenter's wiring of these is tested there.
@MainActor
struct WorkoutSessionHighlightsTests {

    private func set(reps: Int? = 5, weightKg: Double? = 100, durationSec: Int? = nil, isWarmup: Bool = false, completed: Bool = true) -> WorkoutSetModel {
        WorkoutSetModel(
            id: UUID().uuidString,
            authorId: "friend",
            index: 1,
            reps: reps,
            weightKg: weightKg,
            durationSec: durationSec,
            isWarmup: isWarmup,
            completedAt: completed ? DashboardFixture.date(day: 2) : nil,
            dateCreated: DashboardFixture.date(day: 2)
        )
    }

    private func exercise(_ name: String, mode: TrackingMode = .weightReps, sets: [WorkoutSetModel]) -> WorkoutExerciseModel {
        WorkoutExerciseModel(id: UUID().uuidString, authorId: "friend", templateId: name, name: name, trackingMode: mode, index: 1, sets: sets)
    }

    private func session(
        _ id: String,
        day: Int,
        author: String = "friend",
        finished: Bool = true,
        isRestDay: Bool = false,
        _ exercises: WorkoutExerciseModel...
    ) -> WorkoutSessionModel {
        DashboardFixture.session(id: id, author: author, on: DashboardFixture.date(day: day), finished: finished, isRestDay: isRestDay, exercises: exercises)
    }

    private func records(_ current: WorkoutSessionModel, _ prior: [WorkoutSessionModel]) -> [String] {
        WorkoutSessionHighlights.personalRecords(in: current, priorSessions: prior).map { "\($0.exerciseName) \($0.detail)" }
    }

    // MARK: - Personal records

    @Test("Test A Heavier Set Than Ever Before Is A Record")
    func testAHeavierSetThanEverBeforeIsARecord() {
        let before = session("a", day: 2, exercise("Bench", sets: [set(reps: 8, weightKg: 95)]))
        let now = session("b", day: 9, exercise("Bench", sets: [set(reps: 3, weightKg: 100)]))

        #expect(records(now, [before]) == ["Bench 100 kg × 3"])
    }

    @Test("Test Equal Weight With More Reps Is A Record")
    func testEqualWeightWithMoreRepsIsARecord() {
        let before = session("a", day: 2, exercise("Bench", sets: [set(reps: 5, weightKg: 100)]))
        let now = session("b", day: 9, exercise("Bench", sets: [set(reps: 6, weightKg: 100)]))

        #expect(records(now, [before]) == ["Bench 100 kg × 6"])
    }

    @Test("Test Matching The Best Is Not A Record")
    func testMatchingTheBestIsNotARecord() {
        let before = session("a", day: 2, exercise("Bench", sets: [set(reps: 5, weightKg: 100)]))
        let now = session("b", day: 9, exercise("Bench", sets: [set(reps: 5, weightKg: 100), set(reps: 10, weightKg: 90)]))

        #expect(records(now, [before]).isEmpty)
    }

    /// A first-ever lift has nothing to beat, so it is not flagged — a first workout would
    /// otherwise be a card of nothing but badges.
    @Test("Test A First Ever Lift Is Not A Record")
    func testAFirstEverLiftIsNotARecord() {
        let now = session("b", day: 9, exercise("Bench", sets: [set()]), exercise("Squat", sets: [set()]))

        #expect(records(now, []).isEmpty)
        #expect(records(now, [now]).isEmpty)
    }

    @Test("Test Later Sessions And Other Authors Are Ignored")
    func testLaterSessionsAndOtherAuthorsAreIgnored() {
        let before = session("a", day: 2, exercise("Bench", sets: [set(weightKg: 90)]))
        let later = session("c", day: 16, exercise("Bench", sets: [set(weightKg: 150)]))
        let someoneElse = session("d", day: 3, author: "other", exercise("Bench", sets: [set(weightKg: 150)]))
        let now = session("b", day: 9, exercise("Bench", sets: [set(weightKg: 100)]))

        #expect(records(now, [before, later, someoneElse]) == ["Bench 100 kg × 5"])
    }

    @Test("Test Warm Ups, Unfinished Sets And Unfinished Sessions Do Not Count")
    func testWarmUpsUnfinishedSetsAndUnfinishedSessionsDoNotCount() {
        let before = session("a", day: 2, exercise("Bench", sets: [set(weightKg: 90)]))
        let abandoned = session("x", day: 3, finished: false, exercise("Bench", sets: [set(weightKg: 150)]))
        let now = session("b", day: 9, exercise("Bench", sets: [
            set(weightKg: 95),
            set(weightKg: 200, isWarmup: true),
            set(weightKg: 180, completed: false)
        ]))

        #expect(records(now, [before, abandoned]) == ["Bench 95 kg × 5"])
    }

    @Test("Test At Most Three Records Are Shown")
    func testAtMostThreeRecordsAreShown() {
        let names = ["Bench", "Squat", "Deadlift", "Row"]
        let before = DashboardFixture.session(id: "a", author: "friend", on: DashboardFixture.date(day: 2), exercises: names.map { exercise($0, sets: [set(weightKg: 50)]) })
        let now = DashboardFixture.session(id: "b", author: "friend", on: DashboardFixture.date(day: 9), exercises: names.map { exercise($0, sets: [set(weightKg: 60)]) })

        #expect(records(now, [before]) == ["Bench 60 kg × 5", "Squat 60 kg × 5", "Deadlift 60 kg × 5"])
    }

    @Test("Test Reps Only And Timed Exercises Compare Their Own Measure")
    func testRepsOnlyAndTimedExercisesCompareTheirOwnMeasure() {
        let before = session(
            "a", day: 2,
            exercise("Pull Up", mode: .repsOnly, sets: [set(reps: 10, weightKg: nil)]),
            exercise("Plank", mode: .timeOnly, sets: [set(reps: nil, weightKg: nil, durationSec: 60)])
        )
        let now = session(
            "b", day: 9,
            exercise("Pull Up", mode: .repsOnly, sets: [set(reps: 12, weightKg: nil)]),
            exercise("Plank", mode: .timeOnly, sets: [set(reps: nil, weightKg: nil, durationSec: 90)])
        )

        #expect(records(now, [before]) == ["Pull Up 12 reps", "Plank 1:30"])
    }

    // MARK: - Weekly count

    /// 2 to 8 March 2026 is one week whether the calendar starts on Sunday or Monday (the 2nd is a
    /// Monday, the 8th a Sunday) — day 1 is outside it under a Monday start, so it is left out.
    @Test("Test The Weekly Count Counts Only Finished Non Rest Sessions Earlier That Week")
    func testTheWeeklyCountCountsOnlyFinishedNonRestSessionsEarlierThatWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let now = session("now", day: 5)
        let history = [
            session("mon", day: 2),
            session("tue", day: 3),
            session("rest", day: 3, isRestDay: true),
            session("open", day: 4, finished: false),
            session("theirs", day: 4, author: "other"),
            session("lastWeek", day: 1),
            session("laterThisWeek", day: 7),
            now
        ]

        #expect(WorkoutSessionHighlights.weeklyWorkoutNumber(of: now, history: history, calendar: calendar) == 3)
    }
}
