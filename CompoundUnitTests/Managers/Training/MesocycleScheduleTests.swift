//
//  MesocycleScheduleTests.swift
//  CompoundUnitTests
//
//  The schedule is a queue: today's workout is the next one not done since the block started,
//  whatever the calendar says. Each case is one situation a user reported or asked about.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct MesocycleScheduleTests {

    private nonisolated static let calendar = Calendar(identifier: .gregorian)
    /// Wednesday 30 September 2026, 09:00 — mid-week, the day the original bug was reported.
    private nonisolated static let wednesday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 9))!

    private func day(_ name: String, hasExercises: Bool = true) -> WorkoutTemplateModel {
        WorkoutTemplateModel(
            id: name.lowercased(),
            authorId: "me",
            name: name,
            exercises: hasExercises ? [WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)] : []
        )
    }

    /// A, rest, B, rest, C, rest, rest — a week-long microcycle like the prebuilt mesocycles.
    private var days: [WorkoutTemplateModel] {
        [day("A"), day("Rest 1", hasExercises: false), day("B"), day("Rest 2", hasExercises: false),
         day("C"), day("Rest 3", hasExercises: false), day("Rest 4", hasExercises: false)]
    }

    private func mesocycle(cycles: Int = 4) -> Mesocycle {
        Mesocycle(id: "program-1", authorId: "me", name: "Block", icon: "dumbbell", colour: "#FF0000",
                        numMicrocycles: cycles, workoutTemplates: days, dateCreated: Self.wednesday)
    }

    private func run(cycles: Int = 4, startedAt: Date = wednesday, skips: [CycleSkip] = []) -> MesocycleSchedule.Run {
        MesocycleSchedule.Run(mesocycle: mesocycle(cycles: cycles), startedAt: startedAt, skips: skips)
    }

    private func session(_ templateId: String, dayOffset: Int, hour: Int = 10, mesocycleId: String = "program-1") -> WorkoutSessionModel {
        let date = Self.calendar.date(byAdding: .day, value: dayOffset, to: Self.calendar.startOfDay(for: Self.wednesday))!
            .addingTimeInterval(Double(hour) * 3600)
        return WorkoutSessionModel(
            id: "\(templateId)-\(dayOffset)-\(hour)",
            authorId: "me",
            name: templateId.uppercased(),
            workoutTemplateId: templateId,
            mesocycleId: mesocycleId,
            dateCreated: date,
            endedAt: date,
            exercises: []
        )
    }

    private func today(_ run: MesocycleSchedule.Run, _ sessions: [WorkoutSessionModel], dayOffset: Int = 0) -> MicrocycleWorkoutTemplateModelItem? {
        let now = Self.calendar.date(byAdding: .day, value: dayOffset, to: Self.wednesday)!
        return MesocycleSchedule.todayItem(run: run, sessions: sessions, now: now, calendar: Self.calendar)
    }

    @Test("Test A Program Started Mid-Week Starts On Its First Workout")
    func testAMesocycleStartedMidWeekStartsOnItsFirstWorkout() {
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
        let progress = MesocycleSchedule.progress(of: run(), sessions: sessions)

        #expect(progress.cycles[0].filter { $0.completedSessionId != nil }.map(\.dayPlan.id) == ["a", "b"])
        #expect(progress.next?.dayPlan.id == "c")
        #expect(today(run(), sessions)?.dayPlan.id == "b")
    }

    @Test("Test Doing A Later Workout First Fills Its Own Slot")
    func testDoingALaterWorkoutFirstFillsItsOwnSlot() {
        let progress = MesocycleSchedule.progress(of: run(), sessions: [session("c", dayOffset: 0)])

        #expect(progress.cycles[0][4].completedSessionId != nil)
        #expect(progress.next?.dayPlan.id == "a")
    }

    @Test("Test Repeating A Workout Fills The Next Microcycle's Slot")
    func testRepeatingAWorkoutFillsTheNextMicrocyclesSlot() {
        let progress = MesocycleSchedule.progress(of: run(), sessions: [session("a", dayOffset: 0), session("a", dayOffset: 1)])

        #expect(progress.cycles[0][0].completedSessionId != nil)
        #expect(progress.cycles[1][0].completedSessionId != nil)
        #expect(progress.currentCycleIndex == 0)
        #expect(progress.next?.dayPlan.id == "b")
    }

    @Test("Test A Skip Moves The Next Workout Up")
    func testASkipMovesTheNextWorkoutUp() {
        let skip = CycleSkip(mesocycleIndex: 0, cycleIndex: 0, position: 0, templateId: "a", date: Self.wednesday)
        let skipped = run(skips: [skip])

        #expect(MesocycleSchedule.progress(of: skipped, sessions: []).cycles[0][0].state == .skipped)
        #expect(today(skipped, [])?.dayPlan.id == "b")
    }

    @Test("Test A Skip For A Day That No Longer Matches Is Ignored")
    func testASkipForADayThatNoLongerMatchesIsIgnored() {
        let stale = CycleSkip(mesocycleIndex: 0, cycleIndex: 0, position: 0, templateId: "renamed", date: Self.wednesday)
        #expect(MesocycleSchedule.progress(of: run(skips: [stale]), sessions: []).cycles[0][0].state == .open)
    }

    @Test("Test Finishing Every Workout Moves To The Next Microcycle")
    func testFinishingEveryWorkoutMovesToTheNextMicrocycle() {
        let sessions = [session("a", dayOffset: 0), session("b", dayOffset: 2), session("c", dayOffset: 4)]
        let progress = MesocycleSchedule.progress(of: run(), sessions: sessions)

        #expect(progress.currentCycleIndex == 1)
        #expect(progress.next?.dayPlan.id == "a")
        #expect(!progress.isMesocycleComplete)
    }

    @Test("Test Finishing The Last Microcycle Completes The Block")
    func testFinishingTheLastMicrocycleCompletesTheBlock() {
        let sessions = ["a", "b", "c", "a", "b", "c"].enumerated().map { session($1, dayOffset: $0) }
        let progress = MesocycleSchedule.progress(of: run(cycles: 2), sessions: sessions)

        #expect(progress.isMesocycleComplete)
        #expect(progress.currentCycleIndex == 1)
        #expect(today(run(cycles: 2), sessions, dayOffset: 10) == nil)
    }

    @Test("Test Sessions From Before The Block Started Do Not Count")
    func testSessionsFromBeforeTheBlockStartedDoNotCount() {
        let earlier = session("a", dayOffset: -7)
        #expect(MesocycleSchedule.progress(of: run(), sessions: [earlier]).next?.dayPlan.id == "a")
    }

    @Test("Test Another Program's Sessions Do Not Count")
    func testAnotherMesocyclesSessionsDoNotCount() {
        let other = session("a", dayOffset: 0, mesocycleId: "program-2")
        #expect(MesocycleSchedule.progress(of: run(), sessions: [other]).next?.dayPlan.id == "a")
    }

    @Test("Test A Pre-Completed Rest Day Shows As Today's Rest")
    func testAPreCompletedRestDayShowsAsTodaysRest() {
        let restDate = Self.calendar.date(byAdding: .day, value: 1, to: Self.wednesday)!
        let rest = WorkoutSessionModel(
            authorId: "me", name: "Rest 1", workoutTemplateId: "rest 1", mesocycleId: "program-1",
            dateCreated: restDate, endedAt: restDate, exercises: [], isRestDay: true
        )
        let item = today(run(), [session("a", dayOffset: 0), rest], dayOffset: 1)

        #expect(item?.dayPlan.id == "rest 1")
        #expect(item?.dayPlan.exercises.isEmpty == true)
    }

    // MARK: - Rest days

    private func restSession(_ templateId: String, dayOffset: Int, hour: Int = 0) -> WorkoutSessionModel {
        let date = Self.calendar.date(byAdding: .day, value: dayOffset, to: Self.calendar.startOfDay(for: Self.wednesday))!
            .addingTimeInterval(Double(hour) * 3600)
        return WorkoutSessionModel(
            id: "\(templateId)-\(dayOffset)-\(hour)", authorId: "me", name: templateId, workoutTemplateId: templateId,
            mesocycleId: "program-1", dateCreated: date, endedAt: date, exercises: [], isRestDay: true
        )
    }

    private func slot(_ progress: MesocycleSchedule.Progress, cycle: Int = 0, _ templateId: String) -> MesocycleSchedule.Slot? {
        progress.cycles[cycle].first { $0.dayPlan.id == templateId }
    }

    private func at(dayOffset: Int, hour: Int = 12) -> Date {
        Self.calendar.date(byAdding: .day, value: dayOffset, to: Self.calendar.startOfDay(for: Self.wednesday))!
            .addingTimeInterval(Double(hour) * 3600)
    }

    /// Finishing A pre-logs Thursday's rest. On Wednesday evening it is not taken yet.
    @Test("Test A Pre-Logged Rest Is Not Ticked Before Its Day")
    func testAPreLoggedRestIsNotTickedBeforeItsDay() {
        let sessions = [session("a", dayOffset: 0), restSession("rest 1", dayOffset: 1)]

        let wednesday = MesocycleSchedule.progress(of: run(), sessions: sessions, now: at(dayOffset: 0, hour: 20))
        #expect(slot(wednesday, "rest 1")?.state == .open)

        let thursday = MesocycleSchedule.progress(of: run(), sessions: sessions, now: at(dayOffset: 1))
        #expect(slot(thursday, "rest 1")?.completedSessionId == "rest 1-1-0")
        #expect(thursday.next?.dayPlan.id == "b")
    }

    /// Training B on the rest day: finishing it removes the day's rest, and the rest reads as skipped.
    @Test("Test A Rest Day Trained Through Reads As Skipped")
    func testARestDayTrainedThroughReadsAsSkipped() {
        let progress = MesocycleSchedule.progress(
            of: run(), sessions: [session("a", dayOffset: 0), session("b", dayOffset: 1)], now: at(dayOffset: 1, hour: 20)
        )
        #expect(slot(progress, "rest 1")?.state == .skipped)
        #expect(slot(progress, "rest 2")?.state == .open)
        #expect(progress.next?.dayPlan.id == "c")
    }

    /// Every microcycle shares its rest days' plans, so the pre-logged rest after the second A
    /// must tick the second microcycle's rest, not the first one's trained-through rest.
    @Test("Test A Rest Ticks The Rest After Its Own Workout")
    func testARestTicksTheRestAfterItsOwnWorkout() {
        let sessions = [
            session("a", dayOffset: 0), session("b", dayOffset: 0, hour: 12), session("c", dayOffset: 0, hour: 14),
            session("a", dayOffset: 1), restSession("rest 1", dayOffset: 2)
        ]
        let progress = MesocycleSchedule.progress(of: run(), sessions: sessions, now: at(dayOffset: 2))

        #expect(slot(progress, cycle: 0, "rest 1")?.state == .skipped)
        #expect(slot(progress, cycle: 1, "rest 1")?.completedSessionId == "rest 1-2-0")
    }

    /// Ticking a rest after training the same day leaves the card on what was trained.
    @Test("Test Today Shows The Workout Over A Rest Ticked The Same Day")
    func testTodayShowsTheWorkoutOverARestTickedTheSameDay() {
        let sessions = [session("a", dayOffset: 0, hour: 10), restSession("rest 1", dayOffset: 0, hour: 11)]
        let item = MesocycleSchedule.todayItem(run: run(), sessions: sessions, now: at(dayOffset: 0, hour: 12), calendar: Self.calendar)

        #expect(item?.dayPlan.id == "a")
        #expect(item?.isCompleted == true)
    }

    // MARK: - Accounts from before plans

    /// The old schedule counted every session the mesocycle had, so a user who has not finished a
    /// whole block keeps every tick, including sessions from before the mesocycle was created.
    @Test("Test A Legacy Run Counts All Of The Program's History")
    func testALegacyRunCountsAllOfTheMesocyclesHistory() {
        let beforeCreation = session("a", dayOffset: -30)
        let legacy = MesocycleSchedule.legacyRun(mesocycle: mesocycle(), sessions: [beforeCreation])

        #expect(legacy.startedAt == Date(timeIntervalSince1970: 0))
        #expect(MesocycleSchedule.progress(of: legacy, sessions: [beforeCreation]).next?.dayPlan.id == "b")
    }

    /// The old schedule went back to the first microcycle after the last. A user past the end of
    /// the block resumes where it had them, not on a finished block with nothing scheduled.
    @Test("Test A Legacy Run Resumes After The Last Full Pass Through The Block")
    func testALegacyRunResumesAfterTheLastFullPass() {
        // Two microcycles a block: two full passes, then A of the third.
        let sessions = ["a", "b", "c", "a", "b", "c", "a", "b", "c", "a", "b", "c", "a"]
            .enumerated().map { session($1, dayOffset: $0) }
        let legacy = MesocycleSchedule.legacyRun(mesocycle: mesocycle(cycles: 2), sessions: sessions)
        let progress = MesocycleSchedule.progress(of: legacy, sessions: sessions)

        #expect(legacy.startedAt > sessions[11].endedAt!)
        #expect(progress.currentCycleIndex == 0)
        #expect(progress.cycles[0][0].completedSessionId == sessions[12].id)
        #expect(progress.next?.dayPlan.id == "b")
    }

    @Test("Test A Legacy Run Exactly At The End Of A Block Starts Fresh")
    func testALegacyRunExactlyAtTheEndOfABlockStartsFresh() {
        let sessions = ["a", "b", "c", "a", "b", "c"].enumerated().map { session($1, dayOffset: $0) }
        let legacy = MesocycleSchedule.legacyRun(mesocycle: mesocycle(cycles: 2), sessions: sessions)

        #expect(MesocycleSchedule.progress(of: legacy, sessions: sessions).next?.dayPlan.id == "a")
        #expect(today(legacy, sessions, dayOffset: 6)?.dayPlan.id == "a")
    }

    // MARK: - Joining part-way

    @Test("Test Joining At A Later Microcycle Schedules From There")
    func testJoiningAtALaterMicrocycleSchedulesFromThere() {
        var joined = run()
        joined.firstMicrocycleIndex = 2
        let progress = MesocycleSchedule.progress(of: joined, sessions: [])

        #expect(progress.currentCycleIndex == 2)
        #expect(progress.cycles[1].filter { !$0.isRest }.allSatisfy { $0.state == .beforeStart })
        #expect(progress.cycles[1].filter(\.isRest).allSatisfy { $0.state == .open })
        #expect(today(joined, [])?.dayPlan.id == "a")
    }

    // MARK: - Today's microcycle

    /// Starting today's workout picks that week's targets, so today's entry says which week it is.
    @Test("Test Today's Workout Carries Its Microcycle")
    func testTodaysWorkoutCarriesItsMicrocycle() {
        #expect(today(run(), [])?.cycleIndex == 1)

        let firstPass = [session("a", dayOffset: 0), session("b", dayOffset: 2), session("c", dayOffset: 4)]
        let item = today(run(), firstPass, dayOffset: 7)
        #expect(item?.dayPlan.id == "a")
        #expect(item?.cycleIndex == 2)
        // Done today, it keeps the week it was done in.
        #expect(today(run(), firstPass + [session("a", dayOffset: 7, hour: 8)], dayOffset: 7)?.cycleIndex == 2)
    }

    /// A rest the second microcycle's A pre-logged for late tomorrow is that microcycle's rest.
    @Test("Test A Rest Pre-Logged For Later Today Carries Its Microcycle")
    func testARestPreLoggedForLaterTodayCarriesItsMicrocycle() {
        let sessions = [session("a", dayOffset: 0), session("b", dayOffset: 2), session("c", dayOffset: 4),
                        session("a", dayOffset: 7), restSession("rest 1", dayOffset: 8, hour: 23)]

        let item = today(run(), sessions, dayOffset: 8)

        #expect(item?.dayPlan.id == "rest 1")
        #expect(item?.completedSessionId == "rest 1-8-23")
        #expect(item?.cycleIndex == 2)
    }

    @Test("Test Joining At A Later Microcycle Counts From There")
    func testJoiningAtALaterMicrocycleCountsFromThere() {
        var joined = run()
        joined.firstMicrocycleIndex = 2
        #expect(today(joined, [])?.cycleIndex == 3)
    }

    @Test("Test Without A Mesocycle There Is No Microcycle")
    func testWithoutAMesocycleThereIsNoMicrocycle() {
        #expect(MesocycleSchedule.todayItem(run: nil, sessions: [])?.cycleIndex == nil)
    }

    @Test("Test A Workout Done After Joining Fills The Joined Microcycle")
    func testAWorkoutDoneAfterJoiningFillsTheJoinedMicrocycle() {
        var joined = run()
        joined.firstMicrocycleIndex = 3
        let progress = MesocycleSchedule.progress(of: joined, sessions: [session("a", dayOffset: 0)])

        #expect(progress.cycles[3][0].completedSessionId != nil)
        #expect(progress.next?.dayPlan.id == "b")
    }
}
