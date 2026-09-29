//
//  WorkoutsPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI

@Observable
@MainActor
class WorkoutsPresenter {
    
    private let interactor: WorkoutsInteractor
    private let router: WorkoutsRouter
    
    init(
        interactor: WorkoutsInteractor,
        router: WorkoutsRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onWorkoutPressed(workout: WorkoutTemplateModel) {
        router.showWorkoutTemplateDetailView(
            delegate: WorkoutTemplateDetailDelegate(
                workoutTemplate: workout,
                trainingProgramId: nil,
                onStartWorkoutPressed: { [weak self] in
                    Task { @MainActor in
                        self?.router.showWorkoutTrackerView()
                    }
                }
            )
        )
    }

}
