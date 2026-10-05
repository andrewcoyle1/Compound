//
//  CoachRouter.swift
//  Compound
//

import SwiftUI

@MainActor
protocol CoachRouter: GlobalRouter {
    func showPaywall(isOnboarding: Bool)
    func showCoachChatsView(delegate: CoachChatsDelegate)
    /// Restated so the chat list can open a chat inside the coach's own navigation.
    func showCoachChatView(delegate: CoachDelegate)
    /// Restated so declining consent, which closes the coach, can be observed.
    func dismissScreen()
}

extension CoreRouter: CoachRouter { }

/// How every screen opens the coach. A requirement on each screen's router that offers it, so a
/// presenter can ask for it and a test can see that it did.
@MainActor
protocol AskCoachRouter {
    func showCoach(context: CoachContext)
}

extension CoreRouter: AskCoachRouter {

    /// A sheet with its own navigation, so the chat list can push inside it. Premium and consent
    /// are the coach screen's to check, so every way in behaves the same.
    func showCoach(context: CoachContext) {
        router.showScreen(.sheet) { router in
            builder.coachView(router: router, delegate: CoachDelegate(context: context))
        }
    }

    func showCoachChatView(delegate: CoachDelegate) {
        router.showScreen(.push) { router in
            builder.coachView(router: router, delegate: delegate)
        }
    }
}
