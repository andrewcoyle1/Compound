//
//  RecipeStartPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 20/11/2025.
//

import Foundation

@Observable
@MainActor
class RecipeStartPresenter {
    private let interactor: RecipeStartInteractor
    private let router: RecipeStartRouter

    init(
        interactor: RecipeStartInteractor,
        router: RecipeStartRouter
    ) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
}

extension RecipeStartPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear:     return "RecipeStartView_Appear"
            case .onDisappear:  return "RecipeStartView_Disappear"
            }
        }

        var parameters: [String: Any]? {
            nil
        }

        var type: LogType {
            .analytic
        }
    }
}
