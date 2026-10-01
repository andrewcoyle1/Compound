//
//  GoalSummaryRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol GoalSummaryRouter: OnboardingStepRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif

}

extension CoreRouter: GoalSummaryRouter { }
