//
//  WeeklyStreak.swift
//  Compound
//
//  The app's one streak: consecutive weeks in which the user finished at least their weekly
//  session goal. A rest day never breaks it, which a day streak did to anyone not training daily.
//  Counted through `WorkoutSessionHighlights`' rule, like the circle's weekly goal, so the two
//  cannot disagree about what a session is.
//

import Foundation

struct WeeklyStreak: Equatable {

    enum State: Equatable {
        /// This week's goal is met.
        case met
        /// Not met yet, with enough days left to meet it comfortably.
        case onTrack
        /// A streak to lose, nothing logged today, and every day left is needed: the sessions
        /// still owed are at least the days left in the week, today included.
        case atRisk
        /// No streak and nothing logged this week.
        case none
    }

    /// Weeks in a row the goal was met, this week included once it is met. A week still under
    /// way does not break it.
    let weeks: Int
    let best: Int
    let sessionsThisWeek: Int
    let goal: Int
    /// Days left in the week, today included.
    let daysRemaining: Int
    let trainedToday: Bool
    /// The instant this week ends, and the latest counted session's start: what the server's
    /// reminder needs to judge "at risk" on its own clock.
    let weekEndsAt: Date
    let lastTrainedAt: Date?

    var sessionsRemaining: Int { CircleWeek.remaining(sessions: sessionsThisWeek, goal: goal) }

    var state: State {
        if sessionsThisWeek >= goal { return .met }
        if weeks > 0, !trainedToday, sessionsRemaining >= daysRemaining { return .atRisk }
        if weeks == 0, sessionsThisWeek == 0 { return .none }
        return .onTrack
    }

    /// `goal` is applied to every past week: the app keeps no history of goal changes, so a week
    /// is judged by today's goal.
    static func make(
        sessions: [WorkoutSessionModel],
        userId: String,
        goal: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WeeklyStreak {
        func weekStart(_ date: Date) -> Date {
            calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        }
        func previousWeek(_ start: Date) -> Date {
            calendar.date(byAdding: .weekOfYear, value: -1, to: start) ?? start
        }

        let counted = sessions.filter {
            $0.authorId == userId && $0.endedAt != nil && !$0.isRestDay && $0.deletedAt == nil && $0.dateCreated <= now
        }
        let perWeek = Dictionary(grouping: counted) { weekStart($0.dateCreated) }.mapValues(\.count)
        let met = { (week: Date) in (perWeek[week] ?? 0) >= goal }

        let thisWeek = weekStart(now)
        var weeks = 0
        var week = met(thisWeek) ? thisWeek : previousWeek(thisWeek)
        while met(week) {
            weeks += 1
            week = previousWeek(week)
        }

        var best = 0
        var run = 0
        if let first = perWeek.keys.min() {
            week = first
            while week <= thisWeek {
                run = met(week) ? run + 1 : 0
                best = max(best, run)
                week = calendar.date(byAdding: .weekOfYear, value: 1, to: week) ?? thisWeek.addingTimeInterval(1)
            }
        }

        let today = calendar.startOfDay(for: now)
        let weekEnd = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? today.addingTimeInterval(86_400)
        return WeeklyStreak(
            weeks: weeks,
            best: max(best, weeks),
            sessionsThisWeek: perWeek[thisWeek] ?? 0,
            goal: goal,
            daysRemaining: max(calendar.dateComponents([.day], from: today, to: weekEnd).day ?? 1, 1),
            trainedToday: counted.contains { calendar.isDate($0.dateCreated, inSameDayAs: now) },
            weekEndsAt: weekEnd,
            lastTrainedAt: counted.map(\.dateCreated).max()
        )
    }
}

extension PrivateUserSettings {
    /// These settings with `streak`'s figures, as `streakReminder` in `functions/` reads them.
    func recording(_ streak: WeeklyStreak) -> PrivateUserSettings {
        var copy = self
        copy.weekStreak = streak.weeks
        copy.weekSessions = streak.sessionsThisWeek
        copy.weekGoal = streak.goal
        copy.weekEndsAt = streak.weekEndsAt
        copy.lastTrainedAt = streak.lastTrainedAt
        return copy
    }
}

/// Keeps the server's copy of the streak current: after each finish and on every launch, writing
/// only when something changed.
@MainActor
func recordWeeklyStreak(_ streak: WeeklyStreak, users: UserManager) async throws {
    guard users.privateSettings.recording(streak) != users.privateSettings else { return }
    try await users.updatePrivateSettings { $0 = $0.recording(streak) }
}

extension CoreInteractor {
    /// The signed-in user's streak, from their own sessions and their weekly goal.
    var weeklyStreak: WeeklyStreak {
        WeeklyStreak.make(
            sessions: workoutSessions,
            userId: currentUser?.userId ?? "",
            goal: currentUser.map(CircleWeek.goal(for:)) ?? CircleWeek.defaultGoal
        )
    }

    /// Best-effort: a failed write leaves the reminder working from the last figures.
    func recordWeeklyStreak() async {
        guard currentUser != nil else { return }
        try? await Compound.recordWeeklyStreak(weeklyStreak, users: userManager)
    }
}
