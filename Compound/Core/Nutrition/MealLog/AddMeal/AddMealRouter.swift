//
//  AddMealRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol AddMealRouter: GlobalRouter {
    func showNutritionLibraryPickerView(delegate: NutritionLibraryPickerDelegate)
    func showMealItemAmountViewView(delegate: MealItemAmountViewDelegate)
}

extension CoreRouter: AddMealRouter { }
