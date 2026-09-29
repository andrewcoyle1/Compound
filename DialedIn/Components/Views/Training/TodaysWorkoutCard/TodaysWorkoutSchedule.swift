//
//  TodaysWorkoutSchedule.swift
//  DialedIn
//
//  Which day plan of the active program falls on today, and whether it is done. Lifted out of
//  `TodaysWorkoutCardPresenter` so the home-screen widget snapshot reads the same answer as the
//  card. `DashboardPresenter` still holds its own copy of this body.
//

import Foundation

enum TodaysWorkoutSchedule {

    static func item(
        program: TrainingProgram?,
        sessions: [WorkoutSessionModel],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> MicrocycleWorkoutTemplateModelItem? {
        guard let program,
              !program.workoutTemplates.isEmpty else { return nil }

        let today = calendar.startOfDay(for: now)
        let weekdayIndex = calendar.component(.weekday, from: today) - 1
        let weekStart = calendar.date(byAdding: .day, value: -weekdayIndex, to: today) ?? today

        let dayPlans = program.workoutTemplates
        let completedSessions = completed(sessions, in: program)
        var nextIndex = startIndex(dayPlans: dayPlans, completed: completedSessions) % dayPlans.count

        let weekDates = (0..<7)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
            .map { calendar.startOfDay(for: $0) }
        let weekDateSet = Set(weekDates)

        var itemsByDay: [Date: MicrocycleWorkoutTemplateModelItem] = [:]
        for (session, dayPlan) in completedSessions {
            guard let endedAt = session.endedAt else { continue }
            if session.isRestDay, session.dateCreated > now { continue }
            let day = calendar.startOfDay(for: endedAt)
            guard weekDateSet.contains(day), itemsByDay[day] == nil else { continue }
            itemsByDay[day] = MicrocycleWorkoutTemplateModelItem(
                id: "\(day.timeIntervalSince1970)-\(dayPlan.id)",
                date: day,
                dayPlan: dayPlan,
                completedSessionId: session.id
            )
        }
        for day in weekDates where itemsByDay[day] == nil {
            let dayPlan = dayPlans[nextIndex]
            itemsByDay[day] = MicrocycleWorkoutTemplateModelItem(
                id: "\(day.timeIntervalSince1970)-\(dayPlan.id)",
                date: day,
                dayPlan: dayPlan,
                completedSessionId: nil
            )
            nextIndex = (nextIndex + 1) % dayPlans.count
        }
        return itemsByDay[today]
    }

    /// The program's finished sessions, each paired with its day plan, oldest first.
    private static func completed(
        _ sessions: [WorkoutSessionModel],
        in program: TrainingProgram
    ) -> [(WorkoutSessionModel, WorkoutTemplateModel)] {
        let dayPlans = program.workoutTemplates
        let dayPlanNames = Set(dayPlans.map { $0.name })
        let dayPlanById = Dictionary(uniqueKeysWithValues: dayPlans.map { ($0.id, $0) })
        return sessions
            .compactMap { session -> (WorkoutSessionModel, WorkoutTemplateModel)? in
                guard session.endedAt != nil else { return nil }
                let shouldInclude = session.trainingProgramId == program.id
                    || (session.trainingProgramId == nil && dayPlanNames.contains(session.name))
                guard shouldInclude else { return nil }
                if let id = session.workoutTemplateId, let plan = dayPlanById[id] { return (session, plan) }
                if let plan = dayPlans.first(where: { $0.name == session.name }) { return (session, plan) }
                return nil
            }
            .sorted { ($0.0.endedAt ?? .distantPast) < ($1.0.endedAt ?? .distantPast) }
    }

    /// The first training day not yet done in the current cycle through the program.
    private static func startIndex(
        dayPlans: [WorkoutTemplateModel],
        completed: [(WorkoutSessionModel, WorkoutTemplateModel)]
    ) -> Int {
        let workoutIds = Set(dayPlans.filter { !$0.exercises.isEmpty }.map { $0.id })
        var completedInCurrentCycle = Set<String>()
        for (_, dayPlan) in completed {
            guard workoutIds.contains(dayPlan.id) else { continue }
            completedInCurrentCycle.insert(dayPlan.id)
            if completedInCurrentCycle == workoutIds { completedInCurrentCycle.removeAll() }
        }
        guard !workoutIds.isEmpty else { return 0 }
        return dayPlans.firstIndex { !$0.exercises.isEmpty && !completedInCurrentCycle.contains($0.id) } ?? 0
    }
}
