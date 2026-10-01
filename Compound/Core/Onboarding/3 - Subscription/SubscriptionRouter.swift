//
//  SubscriptionRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol SubscriptionRouter: PaywallExitsRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showPaywall(isOnboarding: Bool)
    func showCompleteAccountSetupView()
}

extension CoreRouter: SubscriptionRouter { }
