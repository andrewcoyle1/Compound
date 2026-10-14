//
//  WorkoutHistoryInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 28/11/2025.
//

@MainActor
protocol WorkoutHistoryInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var workoutSessions: [WorkoutSessionModel] { get }

    func syncAllRemoteDataIfLoggedIn() async
}

extension CoreInteractor: WorkoutHistoryInteractor { }
