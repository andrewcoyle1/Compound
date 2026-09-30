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
    private let delegate: MealAccessoryDelegate

    /// Read live, not copied: SwiftUI keeps this presenter while the accessory stays up, so a copy
    /// taken at init froze the count and calories, and a tap reopened that stale draft.
    var draftMeal: MealLogModel {
        interactor.draftMeal ?? delegate.draftMeal
    }

    init(
        interactor: MealAccessoryInteractor,
        router: MealAccessoryRouter,
        delegate: MealAccessoryDelegate
    ) {
        self.interactor = interactor
        self.router = router
        self.delegate = delegate
    }
    
    func reopenMealLog() {
        router.showAddMealView(delegate: AddMealDelegate(mealLog: draftMeal))
    }
}
