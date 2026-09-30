//
//  WelcomeRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol WelcomeRouter: OnboardingStepRouter {
    func showPaywall(isOnboarding: Bool)
    func showIntroView()
    func showAuthView()
    func showSubscriptionView()
    func switchToCoreModule()
}

extension CoreRouter: WelcomeRouter { }
