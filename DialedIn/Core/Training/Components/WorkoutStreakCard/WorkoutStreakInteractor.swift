//
//  WorkoutStreakInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 13/03/2026.
//

@MainActor
protocol WorkoutStreakInteractor: GlobalInteractor {
    var workoutSessions: [WorkoutSessionModel] { get }
}

extension CoreInteractor: WorkoutStreakInteractor { }
