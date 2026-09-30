//
//  ProgramScheduleTests.swift
//  DialedInUnitTests
//
//  The schedule is a queue: today's workout is the next one not done since the block started,
//  whatever the calendar says. Each case is one situation a user reported or asked about.
//

import Testing
import Foundation
@testable import DialedIn

@MainActor
struct ProgramScheduleTests {

    private static let calendar = Calendar(identifier: .gregorian)
    /// Wednesday 30 September 2026, 09:00 — mid-week, the day the original bug was reported.
    private static let wednesday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 9))!

    private func day(_ name: String, hasExercises: Bool = true) -> WorkoutTemplateModel {
        WorkoutTemplateModel(
            id: name.lowercased(),
            authorId: "me",
            name: name,
            exercises: hasExercises ? [WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)] : []
        )
    }

    /// A, rest, B, rest, C, rest, rest — a week-long microcycle like the prebuilt programs.
    private var days: [WorkoutTemplateModel] {
        [day("A"), day("Rest 1", hasExercises: false), day("B"), day("Rest 2", hasExercises: false),
         day("C"), day("Rest 3", hasExercises: false), day("Rest 4", hasExercises: false)]
    }

    private func program(cycles: Int = 4) -> TrainingProgram {
        TrainingProgram(id: "program-1", authorId: "me", name: "Block", icon: "dumbbell", colour: "#FF0000",
                        numMicrocycles: cycles, workoutTemplates: days, dateCreated: Self.wednesday)
    }

    private func run(cycles: Int = 4, startedAt: Date = wednesday, skips: [PlanSkip] = []) -> ProgramSchedule.Run {
        ProgramSchedule.Run(program: program(cycles: cycles), startedAt: startedAt, skips: skips)
    }

    private func session(_ templateId: String, dayOffset: Int, hour: Int = 10, programId: String = "program-1") -> WorkoutSessionModel {
        let date = Self.calendar.date(byAdding: .day, value: dayOffset, to: Self.calendar.startOfDay(for: Self.wednesday))!
            .addingTimeInterval(Double(hour) * 3600)
        return WorkoutSessionModel(
            id: "\(templateId)-\(dayOffset)-\(hour)",
            authorId: "me",
            name: templateId.uppercased(),
            workoutTemplateId: templateId,
            trainingProgramId: programId,
            dateCreated: date,
            endedAt: date,
            exercises: []
        )
    }

    private func today(_ run: ProgramSchedule.Run, _ sessions: [WorkoutSessionModel], dayOffset: Int = 0) -> MicrocycleWorkoutTemplateModelItem? {
        let now = Self.calendar.date(byAdding: .day, value: dayOffset, to: Self.wednesday)!
        return ProgramSchedule.todayItem(run: run, sessions: sessions, now: now, calendar: Self.calendar)
    }

    @Test("Test A Program Started Mid-Week Starts On Its First Workout")
    func testAProgramStartedMidWeekStartsOnItsFirstWorkout() {
        #expect(today(run(), [])?.dayPlan.id == "a")
    }

    @Test("Test A Missed Day Leaves The Same Workout Next")
    func testAMissedDayLeavesTheSameWorkoutNext() {
        let item = today(run(), [], dayOffset: 3)
        #expect(item?.dayPlan.id == "a")
        #expect(item?.isCompleted == false)
    }

    @Test("Test The Day After A Workout Offers The Next One")
    func testTheDayAfterAWorkoutOffersTheNextOne() {
        #expect(today(run(), [session("a", dayOffset: 0)], dayOffset: 1)?.dayPlan.id == "b")
    }

    @Test("Test A Finished Workout Shows As Done For The Rest Of The Day")
    func testAFinishedWorkoutShowsAsDoneForTheRestOfTheDay() {
        let item = today(run(), [session("a", dayOffset: 0)])
        #expect(item?.dayPlan.id == "a")
        #expect(item?.isCompleted == true)
    }

    @Test("Test Two Workouts In One Day Fill Two Slots")
    func testTwoWorkoutsInOneDayFillTwoSlots() {
        let sessions = [session("a", dayOffset: 0, hour: 10), session("b", dayOffset: 0, hour: 18)]
        let progress = ProgramSchedule.progress(of: run(), sessions: sessions)

        #expect(progress.cycles[0].filter { $0.completedSessionId != nil }.map(\.dayPlan.id) == ["a", "b"])
        #expect(progress.next?.dayPlan.id == "c")
        #expect(today(run(), sessions)?.dayPlan.id == "b")
    }

    @Test("Test Doing A Later Workout First Fills Its Own Slot")
    func testDoingALaterWorkoutFirstFillsItsOwnSlot() {
        let progress = ProgramSchedule.progress(of: run(), sessions: [session("c", dayOffset: 0)])

        #expect(progress.cycles[0][4].completedSessionId != nil)
        #expect(progress.next?.dayPlan.id == "a")
    }

    @Test("Test Repeating A Workout Fills The Next Microcycle's Slot")
    func testRepeatingAWorkoutFillsTheNextMicrocyclesSlot() {
        let progress = ProgramSchedule.progress(of: run(), sessions: [session("a", dayOffset: 0), session("a", dayOffset: 1)])

        #expect(progress.cycles[0][0].completedSessionId != nil)
        #expect(progress.cycles[1][0].completedSessionId != nil)
        #expect(progress.currentCycleIndex == 0)
        #expect(progress.next?.dayPlan.id == "b")
    }

    @Test("Test A Skip Moves The Next Workout Up")
    func testASkipMovesTheNextWorkoutUp() {
        let skip = PlanSkip(blockIndex: 0, cycleIndex: 0, position: 0, templateId: "a", date: Self.wednesday)
        let skipped = run(skips: [skip])

        #expect(ProgramSchedule.progress(of: skipped, sessions: []).cycles[0][0].state == .skipped)
        #expect(today(skipped, [])?.dayPlan.id == "b")
    }

    @Test("Test A Skip For A Day That No Longer Matches Is Ignored")
    func testASkipForADayThatNoLongerMatchesIsIgnored() {
        let stale = PlanSkip(blockIndex: 0, cycleIndex: 0, position: 0, templateId: "renamed", date: Self.wednesday)
        #expect(ProgramSchedule.progress(of: run(skips: [stale]), sessions: []).cycles[0][0].state == .open)
    }

    @Test("Test Finishing Every Workout Moves To The Next Microcycle")
    func testFinishingEveryWorkoutMovesToTheNextMicrocycle() {
        let sessions = [session("a", dayOffset: 0), session("b", dayOffset: 2), session("c", dayOffset: 4)]
        let progress = ProgramSchedule.progress(of: run(), sessions: sessions)

        #expect(progress.currentCycleIndex == 1)
        #expect(progress.next?.dayPlan.id == "a")
        #expect(!progress.isBlockComplete)
    }

    @Test("Test Finishing The Last Microcycle Completes The Block")
    func testFinishingTheLastMicrocycleCompletesTheBlock() {
        let sessions = ["a", "b", "c", "a", "b", "c"].enumerated().map { session($1, dayOffset: $0) }
        let progress = ProgramSchedule.progress(of: run(cycles: 2), sessions: sessions)

        #expect(progress.isBlockComplete)
        #expect(progress.currentCycleIndex == 1)
        #expect(today(run(cycles: 2), sessions, dayOffset: 10) == nil)
    }

    @Test("Test Sessions From Before The Block Started Do Not Count")
    func testSessionsFromBeforeTheBlockStartedDoNotCount() {
        let earlier = session("a", dayOffset: -7)
        #expect(ProgramSchedule.progress(of: run(), sessions: [earlier]).next?.dayPlan.id == "a")
    }

    @Test("Test Another Program's Sessions Do Not Count")
    func testAnotherProgramsSessionsDoNotCount() {
        let other = session("a", dayOffset: 0, programId: "program-2")
        #expect(ProgramSchedule.progress(of: run(), sessions: [other]).next?.dayPlan.id == "a")
    }

    @Test("Test A Pre-Completed Rest Day Shows As Today's Rest")
    func testAPreCompletedRestDayShowsAsTodaysRest() {
        let restDate = Self.calendar.date(byAdding: .day, value: 1, to: Self.wednesday)!
        let rest = WorkoutSessionModel(
            authorId: "me", name: "Rest 1", workoutTemplateId: "rest 1", trainingProgramId: "program-1",
            dateCreated: restDate, endedAt: restDate, exercises: [], isRestDay: true
        )
        let item = today(run(), [session("a", dayOffset: 0), rest], dayOffset: 1)

        #expect(item?.dayPlan.id == "rest 1")
        #expect(item?.dayPlan.exercises.isEmpty == true)
    }
}
