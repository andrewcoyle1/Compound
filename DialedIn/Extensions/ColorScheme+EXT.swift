//
//  ColorScheme+EXT.swift
//  DialedIn
//
//  Created by Andrew Coyle on 20/10/2025.
//

import SwiftUI

/// Legacy colour pairs, kept only because the Live Activity widget compiles this file and uses
/// `foregroundSecondary` (`WorkoutSessionActivity/LiveActivityView.swift`).
///
/// App code uses the design-system tokens instead (`Components/DesignSystem/Palette.swift`):
/// `Color.surface` for `backgroundPrimary`, `Color.canvas` for `backgroundSecondary`, and
/// `.onAccent` for text on an accent fill, which `foregroundPrimary`/`foregroundSecondary` used
/// to fake. WP-15 deletes the members the widget does not need.
extension ColorScheme {
    
    var foregroundPrimary: Color {
        self == .dark ? Color.white : Color.black
    }

    var foregroundSecondary: Color {
        self == .dark ? Color.black : Color.white
    }

    var backgroundPrimary: Color {
        self == .dark ? Color(uiColor: .secondarySystemBackground) : Color(uiColor: .systemBackground)
    }
    
    var backgroundSecondary: Color {
        self == .dark ? Color(uiColor: .systemBackground) : Color(uiColor: .secondarySystemBackground)
    }

}
