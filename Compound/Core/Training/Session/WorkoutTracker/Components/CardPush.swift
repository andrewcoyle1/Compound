//
//  CardPush.swift
//  Compound
//
//  The card swap: a new block's card pushed in from the side of the strip it lies on.
//

import SwiftUI

/// Which side the card list comes in from when its block changes, worked out once per move
/// against the order the old block was shown in (so Do Later still reads as forward).
///
/// Held by the view rather than set by the presenter: Next, Do Later, swap and delete
/// all move the card without going through `setFocus`, and the list going out keeps the
/// transition it was last drawn with, so an edge stored with the move reached only the incoming
/// list. `CardPush` asks here when it runs, and both lists agree.
@MainActor
final class CardSwapEdge {
    private var shownBlockId: String?
    private var shownOrder: [[String]] = []
    private var edge: Edge = .trailing

    /// The edge of the move to `blockId`, or of the last move when the block has not changed.
    @discardableResult
    func edge(to blockId: String?, order: [[String]]) -> Edge {
        if blockId != shownBlockId {
            edge = ActiveWorkout.entryEdge(from: shownBlockId, to: blockId, order: shownOrder)
            shownBlockId = blockId
        }
        shownOrder = order
        return edge
    }
}

/// `.push(from:)` with its edge read as the transition runs, not when the view last updated.
struct CardPush: Transition {
    let edge: @MainActor () -> Edge

    func body(content: Content, phase: TransitionPhase) -> some View {
        let from: CGFloat = edge() == .leading ? -1 : 1
        let shift: CGFloat = switch phase {
        case .willAppear: from
        case .didDisappear: -from
        case .identity: 0
        }
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .visualEffect { view, proxy in
                view.offset(x: shift * proxy.size.width)
            }
    }
}
