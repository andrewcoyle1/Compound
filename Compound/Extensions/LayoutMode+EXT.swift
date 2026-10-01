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

// MARK: - Goal Flow Dismiss Action

/// Environment key for dismissing the standalone goal setting flow
@MainActor
private struct GoalFlowDismissKey: @MainActor EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

@MainActor
extension EnvironmentValues {
    var goalFlowDismissAction: (() -> Void)? {
        get { self[GoalFlowDismissKey.self] }
        set { self[GoalFlowDismissKey.self] = newValue }
    }
}
