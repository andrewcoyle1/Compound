//
//  CircleWeek.swift
//  DialedIn
//
//  The circle's week: each person's goal, how far along they are, who leads, and the Monday recap.
//  Pure functions of users, sessions and a date, so all of it is tested without a manager.
//

import Foundation

enum CircleWeek {

    static let defaultGoal = 3
    static let goalRange = 1...7

    /// UserDefaults key holding the week id whose Monday recap the user dismissed.
    static let summaryDismissedWeekKey = "circleWeeklySummaryDismissedWeekId"

    /// The user's weekly target, 3 when they have not picked one, clamped to 1–7 whatever the
    /// document holds.
    static func goal(for user: UserModel) -> Int {
        min(max(user.weeklySessionGoal ?? defaultGoal, goalRange.lowerBound), goalRange.upperBound)
    }

    /// How full the ring is: 0 to 1, never past full however far over goal someone goes.
    static func progress(sessions: Int, goal: Int) -> Double {
        guard goal > 0 else { return 1 }
        return min(max(Double(sessions) / Double(goal), 0), 1)
    }

    static func remaining(sessions: Int, goal: Int) -> Int {
        max(goal - sessions, 0)
    }

    /// Counted through `WorkoutSessionHighlights`, the same rule as the feed's weekly number.
    static func sessionCount(
        of userId: String,
        inWeekOf date: Date,
        sessions: [WorkoutSessionModel],
        calendar: Calendar = .current
    ) -> Int {
        WorkoutSessionHighlights.sessions(of: userId, inWeekOf: date, history: sessions, calendar: calendar).count
    }

    /// Working-set weight × reps across the user's sessions that week, the leaderboard's tie-break.
    static func volumeKg(
        of userId: String,
        inWeekOf date: Date,
        sessions: [WorkoutSessionModel],
        calendar: Calendar = .current
    ) -> Double {
        WorkoutSessionHighlights.sessions(of: userId, inWeekOf: date, history: sessions, calendar: calendar)
            .flatMap(\.exercises)
            .flatMap(\.sets)
            .filter { !$0.isWarmup }
            .reduce(0) { $0 + ($1.weightKg ?? 0) * Double($1.reps ?? 0) }
    }

    static func isFirstDayOfWeek(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else { return false }
        return !calendar.isDate(yesterday, equalTo: date, toGranularity: .weekOfYear)
    }

    static func isLastDayOfWeek(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else { return false }
        return !calendar.isDate(tomorrow, equalTo: date, toGranularity: .weekOfYear)
    }

    /// Stable across the year boundary: the last days of December can belong to week 1 of the next
    /// year, so this uses `yearForWeekOfYear`, not the calendar year.
    static func weekId(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(parts.yearForWeekOfYear ?? 0)-W\(parts.weekOfYear ?? 0)"
    }

    // MARK: - Leaderboard

    struct Standing: Identifiable {
        let user: UserModel
        let sessions: Int
        let volumeKg: Double
        let goal: Int

        var id: String { user.userId }
        var name: String { user.commonNameCalculated ?? user.fullNameCalculated ?? "Unknown" }
    }

    static func standings(
        users: [UserModel],
        sessions: [WorkoutSessionModel],
        now: Date,
        calendar: Calendar = .current
    ) -> [Standing] {
        ranked(users.map { user in
            Standing(
                user: user,
                sessions: sessionCount(of: user.userId, inWeekOf: now, sessions: sessions, calendar: calendar),
                volumeKg: volumeKg(of: user.userId, inWeekOf: now, sessions: sessions, calendar: calendar),
                goal: goal(for: user)
            )
        })
    }

    /// Most sessions first, then most volume, then by name.
    static func ranked(_ standings: [Standing]) -> [Standing] {
        standings.sorted { lhs, rhs in
            if lhs.sessions != rhs.sessions { return lhs.sessions > rhs.sessions }
            if lhs.volumeKg != rhs.volumeKg { return lhs.volumeKg > rhs.volumeKg }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    // MARK: - Monday recap

    struct Summary: Equatable {
        let weekId: String
        let ownSessions: Int
        let ownGoal: Int
        let circleSessions: Int

        var text: String {
            String(localized: "Last week: you \(String(describing: ownSessions))/\(String(describing: ownGoal)), circle \(String(describing: circleSessions)) \(circleSessions == 1 ? String(localized: "session") : String(localized: "sessions"))")
        }
    }

    /// Last week's recap, shown on the first day of the week only and until dismissed for that
    /// week. `circle` includes the reader. Goal is today's goal: the app keeps no history of it.
    static func summary(
        reader: UserModel,
        circle: [UserModel],
        sessions: [WorkoutSessionModel],
        now: Date,
        dismissedWeekId: String?,
        calendar: Calendar = .current
    ) -> Summary? {
        let weekId = weekId(for: now, calendar: calendar)
        guard isFirstDayOfWeek(now, calendar: calendar),
              dismissedWeekId != weekId,
              let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)
        else { return nil }
        return Summary(
            weekId: weekId,
            ownSessions: sessionCount(of: reader.userId, inWeekOf: lastWeek, sessions: sessions, calendar: calendar),
            ownGoal: goal(for: reader),
            circleSessions: circle.reduce(0) {
                $0 + sessionCount(of: $1.userId, inWeekOf: lastWeek, sessions: sessions, calendar: calendar)
            }
        )
    }
}
