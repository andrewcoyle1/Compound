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
    
    func onIngredientPressed(ingredient: FoodModel) {
        router.showFoodDetailView(delegate: FoodDetailDelegate(food: ingredient))
    }
}
