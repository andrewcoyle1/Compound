//
//  IngredientAmountRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol IngredientAmountRouter: GlobalRouter { }

extension CoreRouter: IngredientAmountRouter { }
