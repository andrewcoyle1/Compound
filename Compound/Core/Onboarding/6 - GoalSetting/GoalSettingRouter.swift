//
//  GoalSettingRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol GoalSettingRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showOverarchingObjectiveView()
}

extension CoreRouter: GoalSettingRouter { }
