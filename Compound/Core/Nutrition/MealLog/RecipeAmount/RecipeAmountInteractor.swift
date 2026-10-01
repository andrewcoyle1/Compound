//
//  RecipeAmountInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol RecipeAmountInteractor: GlobalInteractor { }

extension CoreInteractor: RecipeAmountInteractor { }
