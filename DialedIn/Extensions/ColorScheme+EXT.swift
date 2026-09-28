//
//  ColorScheme+EXT.swift
//  DialedIn
//
//  Created by Andrew Coyle on 20/10/2025.
//

import SwiftUI

/// Used only by the Live Activity widget (`WorkoutSessionActivity/LiveActivityView.swift`), which
/// compiles this file and has no design-system tokens. App code uses `.onAccent` for text on an
/// accent fill, and `Color.surface` / `Color.canvas` for backgrounds (`Palette.swift`).
extension ColorScheme {

    /// The opposite of the label colour: white in light mode, black in dark.
    var inverseLabel: Color {
        self == .dark ? Color.black : Color.white
    }
}
