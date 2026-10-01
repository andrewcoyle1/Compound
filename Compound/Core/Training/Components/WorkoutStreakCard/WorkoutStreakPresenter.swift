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
    
    private var completedTrainingDays: Set<Date> {
        let calendar = Calendar.current
        let now = Date()
        return Set(
            interactor.workoutSessions.compactMap { session -> Date? in
                guard session.endedAt != nil else { return nil }
                if session.isRestDay, session.dateCreated > now { return nil }
                return calendar.startOfDay(for: session.dateCreated)
            }
        )
    }

    var workoutStreakCount: Int {
        let days = completedTrainingDays.sorted()
        guard !days.isEmpty else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // If the user hasn't worked out today, start from yesterday (streak is "at risk" but still alive)
        var day = days.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    var isStreakActive: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return completedTrainingDays.contains(today)
    }

    var isStreakAtRisk: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard !completedTrainingDays.contains(today) else { return false }
        // Safe: adding days to a valid date never returns nil.
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        return completedTrainingDays.contains(yesterday)
    }

    var longestStreak: Int {
        let days = completedTrainingDays.sorted()
        guard !days.isEmpty else { return 0 }
        let calendar = Calendar.current
        var longest = 1, current = 1
        for index in 1..<days.count {
            if calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    var totalWorkouts: Int {
        interactor.workoutSessions.filter { $0.endedAt != nil && !$0.isRestDay }.count
    }

    /// The first day of this week in the user's own calendar. Counting back to weekday 1 always
    /// started the row on Sunday, even where the week starts on Monday.
    var startOfWeek: Date {
        let calendar = Calendar.current
        return calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
    }

    var workoutDaysThisWeek: Set<Date> {
        let calendar = Calendar.current
        let weekStart = startOfWeek
        let weekDays = Set((0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        })
        return completedTrainingDays.intersection(weekDays)
    }

}
