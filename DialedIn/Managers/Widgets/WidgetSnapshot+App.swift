//
//  WidgetSnapshot+App.swift
//  DialedIn
//
//  The app's side of the home-screen widgets: building a `WidgetSnapshot` from the managers and
//  writing it to the App Group. Called when a session finishes (`finishWorkout`) and when the
//  weekly goal changes (`updateWeeklySessionGoal`).
//

import Foundation

extension WidgetSnapshot {

    /// `sessions` is the reader's history, including a session that has just finished and may not
    /// have come back through the listener yet.
    static func make(
        userId: String,
        run: ProgramSchedule.Run?,
        sessions: [WorkoutSessionModel],
        streak: Int?,
        weeklyGoal: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WidgetSnapshot {
        let item = ProgramSchedule.todayItem(run: run, sessions: sessions, now: now, calendar: calendar)
        return WidgetSnapshot(
            todaysWorkout: item.map {
                TodaysWorkout(
                    name: $0.dayPlan.name,
                    exerciseCount: $0.dayPlan.exercises.count,
                    isRestDay: $0.dayPlan.exercises.isEmpty,
                    isCompleted: $0.isCompleted
                )
            },
            day: calendar.startOfDay(for: now),
            currentStreak: streak ?? 0,
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
    programs: TrainingProgramManager,
    plans: TrainingPlanManager?,
    sessions: [WorkoutSessionModel],
    streak: Int?,
    weeklyGoal: Int? = nil
) {
    guard let user = users.currentUser else { return }
    WidgetSnapshotStore.write(.make(
        userId: user.userId,
        run: plans?.run(for: programs.activeProgram(for: user))
            ?? programs.activeProgram(for: user).map { ProgramSchedule.Run(program: $0, startedAt: $0.dateCreated) },
        sessions: sessions,
        streak: streak,
        weeklyGoal: weeklyGoal ?? CircleWeek.goal(for: user)
    ))
}

// MARK: - Widgets

extension CoreInteractor {

    /// After the goal is saved, before the listener brings the user document back, so the new goal
    /// is passed in rather than read.
    func refreshWidgetSnapshot(weeklyGoal: Int? = nil) {
        DialedIn.refreshWidgetSnapshot(
            users: userManager,
            programs: trainingProgramManager,
            plans: trainingPlanManager,
            sessions: workoutSessionManager.workoutSessions,
            streak: streakManager.currentStreakData.currentStreak,
            weeklyGoal: weeklyGoal
        )
    }
}
