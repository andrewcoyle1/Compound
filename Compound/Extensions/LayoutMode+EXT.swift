//
//  LayoutMode+EXT.swift
//  Compound
//
//  Created by Andrew Coyle on 18/10/2025.
//

import SwiftUI

/// Defines the current layout mode of the app
enum LayoutMode {
    case tabBar
    case splitView
}

/// Environment key for tracking the current layout mode
private struct LayoutModeKey: EnvironmentKey {
    static let defaultValue: LayoutMode = .tabBar
}

extension EnvironmentValues {
    var layoutMode: LayoutMode {
        get { self[LayoutModeKey.self] }
        set { self[LayoutModeKey.self] = newValue }
    }
}

extension View {
    /// Sets the layout mode for this view and its children
    func layoutMode(_ mode: LayoutMode) -> some View {
        environment(\.layoutMode, mode)
    }
}
