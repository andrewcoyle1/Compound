//
//  MealAccessoryPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI

@Observable
@MainActor
class MealAccessoryPresenter {
    
    private let interactor: MealAccessoryInteractor
    private let router: MealAccessoryRouter
    var draftMeal: MealLogModel
    
    init(
        interactor: MealAccessoryInteractor,
        router: MealAccessoryRouter,
        delegate: MealAccessoryDelegate
    ) {
        self.interactor = interactor
        self.router = router
        self.draftMeal = delegate.draftMeal
    }
    
    func reopenMealLog() {
        router.showAddMealView(delegate: AddMealDelegate(mealLog: draftMeal))
    }
}
