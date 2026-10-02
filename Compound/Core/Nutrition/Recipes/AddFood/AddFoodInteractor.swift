//
//  AddFoodInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol AddFoodInteractor: GlobalInteractor {
    var foods: [FoodModel] { get }
}

extension CoreInteractor: AddFoodInteractor { }
