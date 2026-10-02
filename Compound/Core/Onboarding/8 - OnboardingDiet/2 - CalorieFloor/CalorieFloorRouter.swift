//
//  CalorieFloorRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol CalorieFloorRouter: GlobalRouter {
    func showCalorieDistributionView(delegate: CalorieDistributionDelegate)
}

extension CoreRouter: CalorieFloorRouter { }
