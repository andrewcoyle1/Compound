//
//  AddFoodRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol AddFoodRouter: GlobalRouter { }

extension CoreRouter: AddFoodRouter { }
