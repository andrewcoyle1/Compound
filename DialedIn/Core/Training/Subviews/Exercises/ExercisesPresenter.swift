//
//  ExercisesPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI

@Observable
@MainActor
class ExercisesPresenter {
    private let interactor: ExercisesInteractor
    private let router: ExercisesRouter
    
    init(
        interactor: ExercisesInteractor,
        router: ExercisesRouter
    ) {
        self.interactor = interactor
        self.router = router
    }

    func onExercisePressed(exercise: ExerciseModel) {
        router.showExerciseModelDetailView(delegate: ExerciseModelDetailDelegate(exerciseModel: exercise))
    }

}
