//
//  SetCompletionState.swift
//  Compound
//
//  The Done column's three states and how each is drawn and read.
//

import SwiftUI

enum SetCompletionState: Equatable {
    case completed
    /// Holds what its tracking mode needs; a tap logs it.
    case ready
    /// Missing reps, a time or a distance, so it cannot be logged yet.
    case notReady

    var systemImage: String {
        switch self {
        case .completed: return Symbol.success
        case .ready: return "circle"
        case .notReady: return "circle.dashed"
        }
    }

    var tint: Color {
        switch self {
        case .completed: return .success
        case .ready: return .secondary
        case .notReady: return .secondary.opacity(0.5)
        }
    }

    var accessibilityValue: String {
        switch self {
        case .completed: return ""
        case .ready: return String(localized: "Ready")
        case .notReady: return String(localized: "Not ready, enter the set first")
        }
    }
}
