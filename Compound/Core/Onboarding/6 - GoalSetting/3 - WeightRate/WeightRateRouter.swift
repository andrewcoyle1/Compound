//
//  WeightRateRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol WeightRateRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showGoalSummaryView(delegate: GoalSummaryDelegate)
}

extension CoreRouter: WeightRateRouter { }
