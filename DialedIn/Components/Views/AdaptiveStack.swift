//
//  AdaptiveStack.swift
//  DialedIn
//
//  Side by side at normal text sizes, stacked at the accessibility sizes, where content laid out
//  in a row either truncates to an ellipsis or wraps a letter per line.
//

import SwiftUI

struct AdaptiveStack<Content: View>: View {

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var horizontalAlignment: HorizontalAlignment = .leading
    var verticalAlignment: VerticalAlignment = .center
    var spacing: CGFloat?
    @ViewBuilder var content: Content

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: horizontalAlignment, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: verticalAlignment, spacing: spacing))
        layout { content }
    }
}

#Preview {
    AdaptiveStack(spacing: 12) {
        Text("Alice Cooper")
        Button("Follow") { }
    }
    .dynamicTypeSize(.accessibility3)
}
