//
//  PreferredDietRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol PreferredDietRouter: GlobalRouter {
    func showCalorieFloorView(delegate: CalorieFloorDelegate)
    func showCalorieDistributionView(delegate: CalorieDistributionDelegate)
}

extension CoreRouter: PreferredDietRouter { }
