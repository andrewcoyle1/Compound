//
//  CalorieDistributionRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol CalorieDistributionRouter: GlobalRouter {
    func showProteinIntakeView(delegate: ProteinIntakeDelegate)
}

extension CoreRouter: CalorieDistributionRouter { }
