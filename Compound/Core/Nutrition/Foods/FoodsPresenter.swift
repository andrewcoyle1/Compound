//
//  FoodsPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 26/10/2025.
//

import Foundation

@Observable
@MainActor
class FoodsPresenter {
    private let interactor: FoodsInteractor
    private let router: FoodsRouter
    
    init(
        interactor: FoodsInteractor,
        router: FoodsRouter
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

    func onIngredientPressed(ingredient: FoodModel) {
        router.showFoodDetailView(delegate: FoodDetailDelegate(food: ingredient))
    }
}

extension FoodsPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear:     return "FoodsView_Appear"
            case .onDisappear:  return "FoodsView_Disappear"
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
