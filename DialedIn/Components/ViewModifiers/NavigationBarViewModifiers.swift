//
//  NavigationBarViewModifiers.swift
//  DialedIn
//

import SwiftUI

extension View {

    /// The tab-root title treatment Music and TV use: a large title on the same line as the
    /// toolbar items, and the whole navigation bar minimising as the content scrolls down, the
    /// way `tabBarMinimizeBehavior(.onScrollDown)` already treats the tab bar.
    ///
    /// The minimisation API is iOS 27. On iOS 26 the title still collapses from large to inline
    /// on scroll; only the bar itself stays put.
    func minimizingLargeTitleBar() -> some View {
        modifier(MinimizingLargeTitleBar())
    }
}

private struct MinimizingLargeTitleBar: ViewModifier {

    func body(content: Content) -> some View {
        // The minimisation modifiers exist only in the iOS 27 SDK (Xcode 27, Swift 6.4); CI still
        // builds with Xcode 26.6, where `#available` alone does not stop the symbols failing to compile.
        #if compiler(>=6.4)
        if #available(iOS 27, *) {
            content
                .toolbarTitleDisplayMode(.inlineLarge)
                .toolbarMinimizationBehavior(.onScrollDown, for: .navigationBar)
                // Keeps a `safeAreaInset(edge: .top)` header pinned while the bar changes height.
                .toolbarMinimizationSafeAreaAdjustment(.enabled, for: .navigationBar)
        } else {
            content
                .toolbarTitleDisplayMode(.inlineLarge)
        }
        #else
        content
            .toolbarTitleDisplayMode(.inlineLarge)
        #endif
    }
}
