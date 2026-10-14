//
//  AddSetButton.swift
//  Compound
//
//  The set table's last row.
//

import SwiftUI

/// A + in a circle in the Set column, as the sets' own numbers are.
struct AddSetButton: View {

    var accessibilityLabel = String(localized: "Add Set")
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    /// The sets' circle (`SetCircle`).
    @ScaledMetric(relativeTo: .caption) private var circleSide: CGFloat = ControlSize.thumbnail - Spacing.xs

    var body: some View {
        Button(action: action) {
            Image(systemName: Symbol.add)
                .font(.label.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: circleSide, height: circleSide)
                .background(Color.tintedSurface(.secondary), in: .circle)
                .overlay {
                    if colorSchemeContrast == .increased {
                        Circle().strokeBorder(.secondary, lineWidth: 1)
                    }
                }
                .frame(minWidth: SetTable.setColumnWidth, minHeight: ControlSize.row)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.xs)
        .listRowInsets(.bottom, Spacing.s)
    }
}
