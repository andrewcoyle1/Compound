//
//  MealAccessoryRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 26/01/2026.
//

protocol MealAccessoryRouter: GlobalRouter {
    func showAddMealView(delegate: AddMealDelegate)
}

extension CoreRouter: MealAccessoryRouter {}
