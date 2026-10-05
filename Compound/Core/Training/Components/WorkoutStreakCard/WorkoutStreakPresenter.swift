//
//  WorkoutStreakPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 13/03/2026.
//

import Foundation

@Observable
@MainActor
class WorkoutStreakPresenter {

    private let interactor: WorkoutStreakInteractor
    private let router: WorkoutStreakRouter

    init(
        interactor: WorkoutStreakInteractor,
        router: WorkoutStreakRouter
    ) {
        self.interactor = interactor
        self.router = router
    }

    var streak: WeeklyStreak { interactor.weeklyStreak }

    /// "6 weeks", through the catalog's plural variations.
    var weeksText: String {
        String(localized: "\(streak.weeks) weeks")
    }

    var bestText: String {
        String(localized: "\(streak.best) weeks")
    }

    /// "2 of 3 this week".
    var thisWeekText: String {
        String(localized: "\(streak.sessionsThisWeek) of \(streak.goal) this week")
    }

    var totalWorkouts: Int {
        interactor.workoutSessions.filter { $0.endedAt != nil && !$0.isRestDay && $0.deletedAt == nil }.count
    }

    /// The first day of this week in the user's own calendar. Counting back to weekday 1 always
    /// started the row on Sunday, even where the week starts on Monday.
    var startOfWeek: Date {
        let calendar = Calendar.current
        return calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
    }

    /// Days this week with a session that counts toward the goal; rest days do not.
    var workoutDaysThisWeek: Set<Date> {
        let calendar = Calendar.current
        let weekStart = startOfWeek
        return Set(interactor.workoutSessions.compactMap { session -> Date? in
            guard session.endedAt != nil, !session.isRestDay, session.deletedAt == nil,
                  calendar.isDate(session.dateCreated, equalTo: weekStart, toGranularity: .weekOfYear) else { return nil }
            return calendar.startOfDay(for: session.dateCreated)
        })
    }
}
