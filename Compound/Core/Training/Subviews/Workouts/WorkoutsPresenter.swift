//
//  WorkoutsPresenter.swift
//  Compound
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
                mesocycleId: nil,
                onStartWorkoutPressed: { [weak self] in
                    Task { @MainActor in
                        self?.router.showWorkoutTrackerView()
                    }
                }
            )
        )
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear:     return "WorkoutsView_Appear"
            case .onDisappear:  return "WorkoutsView_Disappear"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
    }
}
