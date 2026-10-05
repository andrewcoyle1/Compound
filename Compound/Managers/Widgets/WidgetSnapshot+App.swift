//
//  WidgetSnapshot+App.swift
//  Compound
//
//  The app's side of the home-screen widgets: building a `WidgetSnapshot` from the managers and
//  writing it to the App Group. Called whenever the app goes to the background, which catches
//  every change made in it, and straight away where a change can happen without the app ever
//  coming forward: a session finished from the Live Activity.
//

import Foundation

extension WidgetSnapshot {

    /// `sessions` is the reader's history, including a session that has just finished and may not
    /// have come back through the listener yet.
    static func make(
        userId: String,
        run: MesocycleSchedule.Run?,
        sessions: [WorkoutSessionModel],
        weeklyGoal: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WidgetSnapshot {
        func workout(on date: Date) -> TodaysWorkout? {
            MesocycleSchedule.todayItem(run: run, sessions: sessions, now: date, calendar: calendar).map {
                TodaysWorkout(
                    name: $0.dayPlan.name,
                    exerciseCount: $0.dayPlan.exercises.count,
                    isRestDay: $0.dayPlan.exercises.isEmpty,
                    isCompleted: $0.isCompleted
                )
            }
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        return WidgetSnapshot(
            todaysWorkout: workout(on: now),
            upcomingWorkout: tomorrow.flatMap(workout(on:)),
            day: calendar.startOfDay(for: now),
            currentStreak: WeeklyStreak.make(sessions: sessions, userId: userId, goal: weeklyGoal, now: now, calendar: calendar).weeks,
            sessionsThisWeek: CircleWeek.sessionCount(of: userId, inWeekOf: now, sessions: sessions, calendar: calendar),
            weeklyGoal: weeklyGoal,
            updatedAt: now
        )
    }
}

/// Builds from the managers' current state and writes it. Signed out writes nothing.
@MainActor
func refreshWidgetSnapshot(
    users: UserManager,
    mesocycles: MesocycleManager,
    macrocycles: MacrocycleManager?,
    sessions: [WorkoutSessionModel],
    weeklyGoal: Int? = nil
) {
    guard let user = users.currentUser else { return }
    WidgetSnapshotStore.write(.make(
        userId: user.userId,
        run: macrocycles?.run(for: mesocycles.activeMesocycle(for: user), sessions: sessions)
            ?? mesocycles.activeMesocycle(for: user).map { MesocycleSchedule.legacyRun(mesocycle: $0, sessions: sessions) },
        sessions: sessions,
        weeklyGoal: weeklyGoal ?? CircleWeek.goal(for: user)
    ))
}

// MARK: - Widgets

extension CoreInteractor {

    /// After the goal is saved, before the listener brings the user document back, so the new goal
    /// is passed in rather than read.
    func refreshWidgetSnapshot(weeklyGoal: Int? = nil) {
        Compound.refreshWidgetSnapshot(
            users: userManager,
            mesocycles: mesocycleManager,
            macrocycles: macrocycleManager,
            sessions: workoutSessionManager.workoutSessions,
            weeklyGoal: weeklyGoal
        )
    }
}
