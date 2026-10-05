//
//  ExercisesPresenter.swift
//  Compound
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
            case .onAppear:     return "ExercisesView_Appear"
            case .onDisappear:  return "ExercisesView_Disappear"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
    }
}
