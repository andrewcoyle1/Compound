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
            case .onAppear:     return "WorkoutNotesView_Appear"
            case .onDisappear:  return "WorkoutNotesView_Disappear"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
    }
}
