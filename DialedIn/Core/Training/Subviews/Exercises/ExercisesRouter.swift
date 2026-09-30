//
//  ExercisesRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/11/2025.
//

@MainActor
protocol ExercisesRouter: GlobalRouter {
    func showCreateExerciseView()
    func showExerciseModelDetailView(delegate: ExerciseModelDetailDelegate)
}

extension CoreRouter: ExercisesRouter { }
