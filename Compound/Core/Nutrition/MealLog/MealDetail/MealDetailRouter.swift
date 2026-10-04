//
//  MealDetailRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol MealDetailRouter: GlobalRouter {
    func showAddMealView(delegate: AddMealDelegate)
}

extension CoreRouter: MealDetailRouter { }
