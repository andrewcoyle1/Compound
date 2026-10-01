//
//  OnboardingCompletedRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol OnboardingCompletedRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif

    func switchToCoreModule()
}

extension CoreRouter: OnboardingCompletedRouter { }
