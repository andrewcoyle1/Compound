//
//  CustomisingDietProgramRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol CustomisingDietProgramRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showPreferredDietView()
    func showDietPlanView(delegate: DietPlanDelegate)
}

extension CoreRouter: CustomisingDietProgramRouter { }
