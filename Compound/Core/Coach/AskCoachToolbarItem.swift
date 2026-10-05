//
//  AskCoachToolbarItem.swift
//  Compound
//
//  The one way into the coach from a screen's toolbar, so every entry point looks and reads the
//  same.
//

import SwiftUI

struct AskCoachToolbarItem: ToolbarContent {

    var placement: ToolbarItemPlacement = .topBarTrailing
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: placement) {
            Button("Ask Coach", systemImage: Symbol.coach, action: action)
                .accessibilityHint("Opens the coach about what this screen shows")
        }
    }
}
