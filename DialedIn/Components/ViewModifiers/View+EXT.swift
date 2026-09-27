//
//  View+EXT.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/6/24.
//

import SwiftUI

extension View {

    @available(*, deprecated, message: "Use Stat / Chip, see docs/specs/ui-framework/CONTRACT.md")
    func badgeButton() -> some View {
        chipStyle(tint: .accentColor, filled: true)
    }

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
}
