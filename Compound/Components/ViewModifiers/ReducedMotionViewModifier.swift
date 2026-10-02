//
//  ReducedMotionViewModifier.swift
//  Compound
//
//  Created by Andrew Coyle on 24/09/2026.
//

import SwiftUI

/// Runs `body` with `animation`, or with no animation at all when Reduce Motion is on.
/// For decorative motion (count-ups, ring fills, bounces) that has no state-change meaning to preserve.
@MainActor
func withReducedMotionAnimation<Result>(_ animation: Animation, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : animation, body)
}

extension View {
    /// `.animation(_:value:)` that falls back to a short crossfade when Reduce Motion is on.
    func reducedMotionAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        modifier(ReducedMotionAnimationModifier(animation: animation, value: value))
    }
}

private struct ReducedMotionAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation?
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .easeInOut(duration: 0.2) : animation, value: value)
    }
}
