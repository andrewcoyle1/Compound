//
//  View+EXT.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/6/24.
//

import SwiftUI

extension View {

    func badgeButton() -> some View {
        self
            .font(.caption)
            .bold()
            .foregroundStyle(Color(uiColor: .systemBackground))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.accentColor)
            .cornerRadius(6)
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
