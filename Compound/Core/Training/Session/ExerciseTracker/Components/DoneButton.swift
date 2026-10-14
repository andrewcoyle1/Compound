//
//  DoneButton.swift
//  Compound
//
//  The row's Done column: its three states, and the button that logs the set or un-logs it.
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

/// Logs the set, or un-logs it once logged; disabled while the set is missing what it needs.
/// Each state has its own symbol and spoken value, so none is told apart by colour alone.
struct DoneButton: View {

    let state: SetCompletionState
    /// The row's name, "Set 2", so Voice Control can tell "Complete Set 2" from "Complete Set 3".
    let setName: String
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            Image(systemName: state.systemImage)
                .font(.title3)
                .foregroundStyle(state.tint)
                .frame(width: ControlSize.row, height: ControlSize.row)
                .contentShape(.rect)
        }
        .accessibilityLabel(state == .completed ? String(localized: "\(setName) completed") : String(localized: "Complete \(setName)"))
        .accessibilityValue(state.accessibilityValue)
        .buttonStyle(.plain)
        .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : SetTable.doneColumnWidth, alignment: .center)
        .frame(minWidth: SetTable.doneColumnWidth)
        .disabled(state == .notReady)
    }
}
