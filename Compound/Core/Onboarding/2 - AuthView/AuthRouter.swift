//
//  AuthRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

import SwiftUI

@MainActor
protocol AuthRouter: OnboardingStepRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    
    func showPaywall(isOnboarding: Bool)
    func showSubscriptionView()
    func switchToCoreModule()
}

extension CoreRouter: AuthRouter { }
