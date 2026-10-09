//
//  MesocycleSchedule.swift
//  Compound
//
//  Where the user is in a block: every microcycle's slots, which are done or skipped, and the
//  next workout. The one answer the Today card, the Active Mesocycle section, the widget and App
//  Intents all read.
//
//  The schedule is a queue, not a calendar. Today's workout is the next one not yet done, so a
//  missed day pushes everything back rather than being lost. Each finished session fills its own
//  template's slot in the lowest microcycle where it is still open, so two in a day both count and
//  doing C before B leaves B next. Only sessions finished after the block started count, so a new
//  or repeated block starts empty whatever the calendar week or earlier history says.
//
//  Rest days never hold the queue up. One is done once a rest-day session for it has arrived,
//  either pre-logged by finishing the workout before it or ticked by the user, and skipped once a
//  workout after it is done without it: the user trained through it.
//

import Foundation

enum MesocycleSchedule {

    /// The block being followed: its mesocycle, when it started, and the slots the user skipped.
    struct Run {
        let mesocycle: Mesocycle
        let startedAt: Date
        var skips: [CycleSkip] = []
        /// Microcycles before this were done before the user joined; nothing is scheduled in them.
        var firstMicrocycleIndex: Int = 0
    }

    enum SlotState: Equatable {
        case open
        case done(sessionId: String, completedAt: Date)
        case skipped
        /// In a microcycle before the one the user joined at.
        case beforeStart
    }

    struct Slot: Identifiable {
        let cycleIndex: Int
        /// Index of the day in the mesocycle's list; a mesocycle may use the same template twice.
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

        var isMesocycleComplete: Bool { next == nil }
    }

    /// Whether the microcycle numbered `cycleIndex` (1-based, as the header shows it) is the
    /// mesocycle's deload, when each session keeps about half its sets at 90 % (`MesocycleDeload`).
    static func isDeload(cycleIndex: Int, of mesocycle: Mesocycle) -> Bool {
        switch mesocycle.deload {
        case .none:  return false
        case .start: return cycleIndex == 1
        case .end:   return cycleIndex == mesocycle.numMicrocycles
        }
    }

    /// Where an account from before plans was. The old schedule counted every session the mesocycle
    /// ever had, name-matched ones included, and went back to the first microcycle after the last,
    /// so the run starts just after the last full pass through the block. Starting from the
    /// mesocycle's creation instead left anyone past their last microcycle with nothing scheduled.
    static func legacyRun(mesocycle: Mesocycle, sessions: [WorkoutSessionModel]) -> Run {
        // The epoch rather than `.distantPast`, which is outside what Firestore can store.
        var startedAt = Date(timeIntervalSince1970: 0)
        while true {
            let progress = progress(of: Run(mesocycle: mesocycle, startedAt: startedAt), sessions: sessions)
            guard progress.isMesocycleComplete,
                  let finishedAt = progress.cycles.joined().filter({ !$0.isRest }).compactMap(\.completedAt).max() else { break }
            startedAt = finishedAt.addingTimeInterval(0.001)
        }
        return Run(mesocycle: mesocycle, startedAt: startedAt)
    }

    static func progress(of run: Run, sessions: [WorkoutSessionModel], now: Date = Date()) -> Progress {
        let dayPlans = run.mesocycle.workoutTemplates
        let cycleCount = max(run.mesocycle.numMicrocycles, 1)
        var cycles = (0..<cycleCount).map { cycle in
            dayPlans.enumerated().map { Slot(cycleIndex: cycle, position: $0.offset, dayPlan: $0.element, state: .open) }
        }

        for cycle in cycles.indices where cycle < run.firstMicrocycleIndex {
            for position in cycles[cycle].indices where !cycles[cycle][position].isRest {
                cycles[cycle][position].state = .beforeStart
            }
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
        fillRestDays(&cycles, run: run, sessions: sessions, now: now)
        return Progress(cycles: cycles)
    }

    /// Each rest-day session fills the first open rest day with its plan after the workout done
    /// before it, so the one pre-logged after A ticks A's rest and not an earlier microcycle's,
    /// which shares its plan. Then an open rest day with a workout done after it was trained
    /// through, and reads as skipped.
    private static func fillRestDays(_ cycles: inout [[Slot]], run: Run, sessions: [WorkoutSessionModel], now: Date) {
        // Queue order. Every microcycle has the same days, so a slot's place is index / width.
        var slots = cycles.flatMap { $0 }
        let rests = sessions
            .filter { session in
                session.isRestDay && session.deletedAt == nil && session.mesocycleId == run.mesocycle.id
                    && session.dateCreated >= run.startedAt && session.dateCreated <= now
            }
            .sorted { $0.dateCreated < $1.dateCreated }

        for rest in rests {
            let fits = { (slot: Slot) in slot.isRest && slot.state == .open && slot.dayPlan.id == rest.workoutTemplateId }
            let anchor = slots.indices
                .filter { !slots[$0].isRest && slots[$0].completedAt.map { $0 < rest.dateCreated } == true }
                .max { (slots[$0].completedAt ?? .distantPast) < (slots[$1].completedAt ?? .distantPast) }
            guard let index = slots.indices[(anchor.map { $0 + 1 } ?? 0)...].first(where: { fits(slots[$0]) }) else { continue }
            slots[index].state = .done(sessionId: rest.id, completedAt: rest.dateCreated)
        }

        var workoutDoneLater = false
        for index in slots.indices.reversed() {
            if !slots[index].isRest {
                workoutDoneLater = workoutDoneLater || slots[index].completedSessionId != nil
            } else if slots[index].state == .open, workoutDoneLater, slots[index].cycleIndex >= run.firstMicrocycleIndex {
                slots[index].state = .skipped
            }
        }

        let width = cycles.first?.count ?? 0
        guard width > 0 else { return }
        cycles = stride(from: 0, to: slots.count, by: width).map { Array(slots[$0..<$0 + width]) }
    }

    /// Today's entry for the Today card, widget and App Intents: the workout finished today if
    /// there is one, a rest day the mesocycle pre-completed for today, or else the next workout.
    /// Nil when there is no mesocycle or the block is finished.
    static func todayItem(
        run: Run?,
        sessions: [WorkoutSessionModel],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> MicrocycleWorkoutTemplateModelItem? {
        guard let run, !run.mesocycle.workoutTemplates.isEmpty else { return nil }
        let today = calendar.startOfDay(for: now)
        let progress = progress(of: run, sessions: sessions, now: now)

        let doneToday = progress.cycles.joined()
            .compactMap { slot -> (Slot, Date)? in
                guard case .done(_, let completedAt) = slot.state, calendar.isDate(completedAt, inSameDayAs: today) else { return nil }
                return (slot, completedAt)
            }
            // A workout over a rest day ticked the same day: the card shows what was trained.
            .max { ($0.0.isRest ? 0 : 1, $0.1) < ($1.0.isRest ? 0 : 1, $1.1) }
        if let (slot, _) = doneToday {
            return item(slot.dayPlan, on: today, sessionId: slot.completedSessionId, cycleIndex: slot.cycleIndex + 1)
        }

        let restToday = sessions.first { session in
            session.isRestDay && session.deletedAt == nil && session.mesocycleId == run.mesocycle.id
                && calendar.isDate(session.dateCreated, inSameDayAs: today)
        }
        if let restToday, let plan = run.mesocycle.workoutTemplates.first(where: { $0.id == restToday.workoutTemplateId }) {
            // Pre-logged for later today, so not ticked yet: its microcycle is where it will tick.
            let ticked = Self.progress(of: run, sessions: sessions, now: max(now, restToday.dateCreated))
                .cycles.joined().first { $0.completedSessionId == restToday.id }
            return item(plan, on: today, sessionId: restToday.id, cycleIndex: ticked.map { $0.cycleIndex + 1 })
        }

        guard let next = progress.next else { return nil }
        return item(next.dayPlan, on: today, sessionId: nil, cycleIndex: next.cycleIndex + 1)
    }

    private static func item(_ plan: WorkoutTemplateModel, on day: Date, sessionId: String?, cycleIndex: Int?) -> MicrocycleWorkoutTemplateModelItem {
        MicrocycleWorkoutTemplateModelItem(
            id: "\(day.timeIntervalSince1970)-\(plan.id)",
            date: day,
            dayPlan: plan,
            completedSessionId: sessionId,
            cycleIndex: cycleIndex
        )
    }

    /// The block's finished workouts since it started, oldest first. Sessions logged before a
    /// mesocycle carried ids are matched by the day's name.
    private static func counted(_ sessions: [WorkoutSessionModel], in run: Run) -> [(WorkoutSessionModel, Date)] {
        let dayPlanNames = Set(run.mesocycle.workoutTemplates.map(\.name))
        return sessions
            .compactMap { session -> (WorkoutSessionModel, Date)? in
                guard let endedAt = session.endedAt, endedAt >= run.startedAt,
                      !session.isRestDay, session.deletedAt == nil else { return nil }
                let belongs = session.mesocycleId == run.mesocycle.id
                    || (session.mesocycleId == nil && dayPlanNames.contains(session.name))
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

/// A slot the user chose to skip. Identified by position as well as template, since a mesocycle may
/// list the same workout twice in a microcycle.
struct CycleSkip: Codable, Sendable, Hashable {
    let mesocycleIndex: Int
    let cycleIndex: Int
    let position: Int
    let templateId: String
    let date: Date

    enum CodingKeys: String, CodingKey {
        case mesocycleIndex = "mesocycle_index"
        case cycleIndex = "cycle_index"
        case position
        case templateId = "template_id"
        case date
    }
}
