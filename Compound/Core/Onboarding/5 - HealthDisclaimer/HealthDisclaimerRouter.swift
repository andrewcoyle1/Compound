//
//  HealthDisclaimerRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol HealthDisclaimerRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showGoalSettingView()
}

extension CoreRouter: HealthDisclaimerRouter { }
