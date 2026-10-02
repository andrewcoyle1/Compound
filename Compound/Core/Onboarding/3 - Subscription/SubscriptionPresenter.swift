//
//  SubscriptionPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class SubscriptionPresenter {
    private let interactor: SubscriptionInteractor
    private let router: SubscriptionRouter

    init(
        interactor: SubscriptionInteractor,
        router: SubscriptionRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    private var exits: PaywallExits {
        PaywallExits(interactor: interactor, router: router, screenName: "SubscriptionInfoView")
    }

    func onContinuePressed() {
        interactor.trackEvent(event: Event.navigate)
        
        // Pending: Free trial (decision 1a, planned): an app-managed trial with no payment sign-up. Offer "Start Free Trial" beside Continue here,
        // store when it started on the user, and have `PremiumAccess.isPremium` grant access until it ends; after that only paying users get in.
        router.showPaywall(isOnboarding: true)
    }

    func onAccountPressed() {
        exits.onAccountPressed()
    }

    func onSignOutPressed() {
        exits.onSignOutPressed()
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif

    enum Event: LoggableEvent {
        case navigate

        var eventName: String {
            switch self {
            case .navigate: return "SubscriptionInfoView_Navigate"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .navigate:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .navigate:
                return .info
            }
        }
    }
}
