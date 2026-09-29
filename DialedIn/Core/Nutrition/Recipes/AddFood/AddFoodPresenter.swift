//
//  AddFoodPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 26/10/2025.
//

import Foundation

@Observable
@MainActor
class AddFoodPresenter {
    private let interactor: AddFoodInteractor
    private let router: AddFoodRouter

    var searchText: String = ""
    
    var foods: [FoodModel] {
        interactor.foods
    }

    /// The library narrowed to foods whose name or description contains the search text.
    var filteredFoods: [FoodModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return foods }
        return foods.filter { food in
            [food.name, food.description].compactMap { $0 }.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    
    init(
        interactor: AddFoodInteractor,
        router: AddFoodRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onIngredientPressed(ingredient: FoodModel, selectedIngredients: inout [FoodModel]) {
        interactor.playHaptic(option: .selection)
        if let index = selectedIngredients.firstIndex(where: { $0.id == ingredient.id }) {
            selectedIngredients.remove(at: index)
        } else {
            selectedIngredients.append(ingredient)
        }
    }
    
    func onDismissPressed() {
        router.dismissScreen()
    }
    
#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif
}
