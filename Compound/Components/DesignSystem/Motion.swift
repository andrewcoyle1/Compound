//
//  Motion.swift
//  Compound
//

import SwiftUI

/// The four animation curves. Always apply them through `reducedMotionAnimation(_:value:)` or
/// `withReducedMotionAnimation(_:_:)` (`Components/ViewModifiers/ReducedMotionViewModifier.swift`),
/// never bare `withAnimation` or `.animation(`.
///
/// - `quick`: selection, toggles, small state flips.
/// - `standard`: content appearing, moving or resizing.
/// - `emphasis`: a moment worth celebrating (a set completed, a PR).
/// - `progress`: rings and bars filling to a value.
extension Animation {
    static let quick: Animation = .snappy
    static let standard: Animation = .smooth
    static let emphasis: Animation = .bouncy
    static let progress: Animation = .easeOut(duration: 1.0)
}
