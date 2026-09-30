//
//  ProgramSchedule.swift
//  DialedIn
//
//  Where the user is in a block: every microcycle's slots, which are done or skipped, and the
//  next workout. The one answer the Today card, the Active Program section, the widget and App
//  Intents all read.
//
//  The schedule is a queue, not a calendar. Today's workout is the next one not yet done, so a
//  missed day pushes everything back rather than being lost. Each finished session fills its own
//  template's slot in the lowest microcycle where it is still open, so two in a day both count and
//  doing C before B leaves B next. Only sessions finished after the block started count, so a new
//  or repeated block starts empty whatever the calendar week or earlier history says.
//

import Foundation

enum ProgramSchedule {

    /// The block being followed: its program, when it started, and the slots the user skipped.
    struct Run {
        let program: TrainingProgram
        let startedAt: Date
        var skips: [PlanSkip] = []
    }

    enum SlotState: Equatable {
        case open
        case done(sessionId: String, completedAt: Date)
        case skipped
    }

    struct Slot: Identifiable {
        let cycleIndex: Int
        /// Index of the day in the program's list; a program may use the same template twice.
        let position: Int
        let dayPlan: WorkoutTemplateModel
        var state: SlotState

        var id: String { "\(cycleIndex)-\(position)-\(dayPlan.id)" }
        var isRest: Bool { dayPlan.exercises.isEmpty }
        var isOpenWorkout: Bool { !isRest && state == .open }

        var completedSessionId: String? {
            if case .done(let sessionId, _) = state { return sessionId }
            return nil
        }

        var completedAt: Date? {
            if case .done(_, let completedAt) = state { return completedAt }
            return nil
        }
    }

    struct Progress {
        /// One array per microcycle, in order.
        let cycles: [[Slot]]

        /// The lowest microcycle with a workout still open; the last one once the block is done.
        var currentCycleIndex: Int {
            cycles.firstIndex { $0.contains(where: \.isOpenWorkout) } ?? max(cycles.count - 1, 0)
        }

        var next: Slot? {
            cycles.lazy.compactMap { $0.first(where: \.isOpenWorkout) }.first
        }

        var isBlockComplete: Bool { next == nil }
    }

    /// Where an account from before plans was. The old schedule counted every session the program
    /// ever had, name-matched ones included, and went back to the first microcycle after the last,
    /// so the run starts just after the last full pass through the block. Starting from the
    /// program's creation instead left anyone past their last microcycle with nothing scheduled.
    static func legacyRun(program: TrainingProgram, sessions: [WorkoutSessionModel]) -> Run {
        // The epoch rather than `.distantPast`, which is outside what Firestore can store.
        var startedAt = Date(timeIntervalSince1970: 0)
        while true {
            let progress = progress(of: Run(program: program, startedAt: startedAt), sessions: sessions)
            guard progress.isBlockComplete,
                  let finishedAt = progress.cycles.joined().compactMap(\.completedAt).max() else { break }
            startedAt = finishedAt.addingTimeInterval(0.001)
        }
        return Run(program: program, startedAt: startedAt)
    }

    static func progress(of run: Run, sessions: [WorkoutSessionModel]) -> Progress {
        let dayPlans = run.program.workoutTemplates
        let cycleCount = max(run.program.numMicrocycles, 1)
        var cycles = (0..<cycleCount).map { cycle in
            dayPlans.enumerated().map { Slot(cycleIndex: cycle, position: $0.offset, dayPlan: $0.element, state: .open) }
        }

        for skip in run.skips where cycles.indices.contains(skip.cycleIndex) {
            let slots = cycles[skip.cycleIndex]
            guard slots.indices.contains(skip.position), slots[skip.position].dayPlan.id == skip.templateId else { continue }
            cycles[skip.cycleIndex][skip.position].state = .skipped
        }

        for (session, endedAt) in counted(sessions, in: run) {
            guard let (cycle, position) = firstOpenSlot(for: session, in: cycles) else { continue }
            cycles[cycle][position].state = .done(sessionId: session.id, completedAt: endedAt)
        }
        return Progress(cycles: cycles)
    }

    /// Today's entry for the Today card, widget and App Intents: the workout finished today if
    /// there is one, a rest day the program pre-completed for today, or else the next workout.
    /// Nil when there is no program or the block is finished.
    static func todayItem(
        run: Run?,
        sessions: [WorkoutSessionModel],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> MicrocycleWorkoutTemplateModelItem? {
        guard let run, !run.program.workoutTemplates.isEmpty else { return nil }
        let today = calendar.startOfDay(for: now)
        let progress = progress(of: run, sessions: sessions)

        let doneToday = progress.cycles.joined()
            .compactMap { slot -> (Slot, Date)? in
                guard case .done(_, let completedAt) = slot.state, calendar.isDate(completedAt, inSameDayAs: today) else { return nil }
                return (slot, completedAt)
            }
            .max { $0.1 < $1.1 }
        if let (slot, _) = doneToday {
            return item(slot.dayPlan, on: today, sessionId: slot.completedSessionId)
        }

        let restToday = sessions.first { session in
            session.isRestDay && session.deletedAt == nil && session.trainingProgramId == run.program.id
                && calendar.isDate(session.dateCreated, inSameDayAs: today)
        }
        if let restToday, let plan = run.program.workoutTemplates.first(where: { $0.id == restToday.workoutTemplateId }) {
            return item(plan, on: today, sessionId: restToday.id)
        }

        guard let next = progress.next else { return nil }
        return item(next.dayPlan, on: today, sessionId: nil)
    }

    private static func item(_ plan: WorkoutTemplateModel, on day: Date, sessionId: String?) -> MicrocycleWorkoutTemplateModelItem {
        MicrocycleWorkoutTemplateModelItem(
            id: "\(day.timeIntervalSince1970)-\(plan.id)",
            date: day,
            dayPlan: plan,
            completedSessionId: sessionId
        )
    }

    /// The block's finished workouts since it started, oldest first. Sessions logged before a
    /// program carried ids are matched by the day's name.
    private static func counted(_ sessions: [WorkoutSessionModel], in run: Run) -> [(WorkoutSessionModel, Date)] {
        let dayPlanNames = Set(run.program.workoutTemplates.map(\.name))
        return sessions
            .compactMap { session -> (WorkoutSessionModel, Date)? in
                guard let endedAt = session.endedAt, endedAt >= run.startedAt,
                      !session.isRestDay, session.deletedAt == nil else { return nil }
                let belongs = session.trainingProgramId == run.program.id
                    || (session.trainingProgramId == nil && dayPlanNames.contains(session.name))
                return belongs ? (session, endedAt) : nil
            }
            .sorted { $0.1 < $1.1 }
    }

    /// The lowest microcycle where this session's own day is still open.
    private static func firstOpenSlot(for session: WorkoutSessionModel, in cycles: [[Slot]]) -> (Int, Int)? {
        for (cycle, slots) in cycles.enumerated() {
            let match = slots.firstIndex { slot in
                guard slot.isOpenWorkout else { return false }
                if let templateId = session.workoutTemplateId { return slot.dayPlan.id == templateId }
                return slot.dayPlan.name == session.name
            }
            if let match { return (cycle, match) }
        }
        return nil
    }
}

/// A slot the user chose to skip. Identified by position as well as template, since a program may
/// list the same workout twice in a microcycle.
struct PlanSkip: Codable, Sendable, Hashable {
    let blockIndex: Int
    let cycleIndex: Int
    let position: Int
    let templateId: String
    let date: Date

    enum CodingKeys: String, CodingKey {
        case blockIndex = "block_index"
        case cycleIndex = "cycle_index"
        case position
        case templateId = "template_id"
        case date
    }
}
