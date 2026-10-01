//
//  OverarchingObjectiveRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol OverarchingObjectiveRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showTargetWeightView(delegate: TargetWeightDelegate)
    func showGoalSummaryView(delegate: GoalSummaryDelegate)
}

extension CoreRouter: OverarchingObjectiveRouter { }
