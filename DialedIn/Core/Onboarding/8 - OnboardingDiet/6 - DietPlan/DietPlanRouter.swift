//
//  DietPlanRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol DietPlanRouter: GlobalRouter {
    func showOnboardingCompletedView()
}

extension CoreRouter: DietPlanRouter { }
