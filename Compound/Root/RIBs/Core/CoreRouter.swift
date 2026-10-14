//
//  CoreRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 20/11/2025.
//

import SwiftUI

@MainActor
struct CoreRouter: GlobalRouter {

    let router: AnyRouter
    let builder: CoreBuilder
        
    func showCommentsView(delegate: CommentsDelegate) {
        router.showScreen(.sheet) { router in
            self.builder.commentsView(router: router, delegate: delegate)
        }
    }

}
