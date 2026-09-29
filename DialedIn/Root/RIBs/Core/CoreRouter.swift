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
        
    func showWarmupSetInfoModal(primaryButtonAction: @escaping () -> Void) {
        router.showModal(
            transition: .move(edge: .bottom),
            backgroundColor: .black.opacity(0.3),
            destination: {
                CustomModalView(
                    title: String(localized: "Warmup Sets"),
                    subtitle: String(localized: "Warmup sets are lighter weight sets performed before your working sets to prepare your muscles and joints. They don't count toward your total volume or personal records."),
                    primaryButtonTitle: "Got it",
                    primaryButtonAction: {
                        primaryButtonAction()
                    },
                    secondaryButtonTitle: "",
                    secondaryButtonAction: {}
                )
            }
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
