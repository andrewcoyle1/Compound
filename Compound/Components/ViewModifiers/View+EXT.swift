//
//  View+EXT.swift
//  Compound
//
//  Created by Andrew Coyle on 10/6/24.
//

import SwiftUI

extension View {

    @ViewBuilder
    func ifSatisfiedCondition<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    func any() -> AnyView {
        AnyView(self)
    }

    /// Swipe actions with the same buttons in a context menu, so a row's actions are not reachable
    /// only by swiping: someone who cannot swipe, and uses neither VoiceOver nor Switch Control,
    /// can still long-press. Use it in place of `swipeActions` on every row.
    func rowActions<Actions: View>(
        edge: HorizontalEdge = .trailing,
        allowsFullSwipe: Bool = true,
        @ViewBuilder _ actions: () -> Actions
    ) -> some View {
        swipeActions(edge: edge, allowsFullSwipe: allowsFullSwipe) { actions() }
            .contextMenu { actions() }
    }
}
