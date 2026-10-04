//
//  DietPlanRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol DietPlanRouter: GlobalRouter {
    func switchToCoreModule()
}

extension CoreRouter: DietPlanRouter { }
