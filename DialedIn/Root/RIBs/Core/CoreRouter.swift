//
//  CoreRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 20/11/2025.
//

import SwiftUI

@MainActor
struct CoreRouter: GlobalRouter {

    let router: AnyRouter
    let builder: CoreBuilder
        
    /// A system alert rather than `CustomModalView`: it scrolls at large text sizes, is modal to
    /// VoiceOver and dismisses itself, so `primaryButtonAction` (which callers used to take the
    /// old overlay down) has nothing left to do.
    func showWarmupSetInfoModal(primaryButtonAction: @escaping () -> Void) {
        showSimpleAlert(
            title: String(localized: "Warmup Sets"),
            subtitle: String(localized: "Warmup sets are lighter weight sets performed before your working sets to prepare your muscles and joints. They don't count toward your total volume or personal records.")
        )
    }

    func showRatingsModal(onYesPressed: @escaping () -> Void, onNoPressed: @escaping () -> Void) {
        router.showModal(transition: .fade, backgroundColor: Color.black.opacity(0.6)) {
            builder.ratingsModal(onYesPressed: onYesPressed, onNoPressed: onNoPressed)
        }
    }

    func showCommentsView(delegate: CommentsDelegate) {
        router.showScreen(.sheet) { router in
            self.builder.commentsView(router: router, delegate: delegate)
        }
    }

}
