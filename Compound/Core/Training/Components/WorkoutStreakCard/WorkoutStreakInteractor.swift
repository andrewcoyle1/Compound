//
//  WorkoutStreakInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 13/03/2026.
//

@MainActor
protocol WorkoutStreakInteractor: GlobalInteractor {
    var workoutSessions: [WorkoutSessionModel] { get }
    var weeklyStreak: WeeklyStreak { get }
}

extension CoreInteractor: WorkoutStreakInteractor { }
