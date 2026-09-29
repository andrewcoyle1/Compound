//
//  BottomCTA.swift
//  DialedIn
//

import SwiftUI

extension View {
    /// Pins a screen's call to action to the bottom safe area, with the standard spacing.
    ///
    /// Pass one or two `CallToActionButton`s, or one plus a plain secondary text button:
    ///
    /// ```swift
    /// List { … }
    ///     .bottomCTA {
    ///         CallToActionButton { presenter.onContinuePressed() } label: { Text("Continue") }
    ///         Button("Skip for now") { presenter.onSkipPressed() }
    ///     }
    /// ```
    ///
    /// Callers add no padding of their own: the buttons are spaced by `Spacing.s` and the stack
    /// sits `Spacing.s` above the bottom edge. `CallToActionButton` pads itself horizontally.
    func bottomCTA<Buttons: View>(@ViewBuilder _ buttons: () -> Buttons) -> some View {
        safeAreaInset(edge: .bottom) {
            // A screen whose button is conditional (`if … { CallToActionButton }`) passes no
            // subviews at times; the bottom padding alone would still push the content up 8 pt.
            Group(subviews: buttons()) { subviews in
                if !subviews.isEmpty {
                    VStack(spacing: Spacing.s) {
                        subviews
                    }
                    .padding(.bottom, Spacing.s)
                }
            }
        }
    }
}
