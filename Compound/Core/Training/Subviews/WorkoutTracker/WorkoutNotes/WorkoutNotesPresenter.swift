//
//  WorkoutNotesPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 05/12/2025.
//

import Foundation

@Observable
@MainActor
class WorkoutNotesPresenter {
    let interactor: WorkoutNotesInteractor
    let router: WorkoutNotesRouter

    init(
        interactor: WorkoutNotesInteractor,
        router: WorkoutNotesRouter
    ) {
        self.interactor = interactor
        self.router = router
    }

    func onDismissPressed() {
        router.dismissScreen()
    }
}
