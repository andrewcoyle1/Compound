//
//  RecipeAmountRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol RecipeAmountRouter: GlobalRouter { }

extension CoreRouter: RecipeAmountRouter { }
