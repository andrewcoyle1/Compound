//
//  ProteinIntakeRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol ProteinIntakeRouter: GlobalRouter {
    func showDietPlanView(delegate: DietPlanDelegate)
}

extension CoreRouter: ProteinIntakeRouter { }
