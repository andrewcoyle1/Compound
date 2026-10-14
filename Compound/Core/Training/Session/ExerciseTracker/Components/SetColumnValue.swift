//
//  SetColumnValue.swift
//  Compound
//
//  A value in the row's Last or Auto column.
//

import SwiftUI

/// Last session's figures or smart progression's suggestion, with the reps left in reserve under
/// them when given. With `onFill`, a tap copies it into the set: not on a logged set, where a
/// stray tap would overwrite what was recorded.
struct SetColumnValue: View {

    let text: String
    var font: Font = .label
    var lineLimit: Int?
    var footnote: String?
    var onFill: (() -> Void)?
    var isLogged = false

    @ScaledMetric(relativeTo: .body) private var cellHeight = SetTable.cellHeight

    var body: some View {
        if let onFill {
            content
                .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
                .contentShape(.rect)
                .anyButton(action: onFill)
                .accessibilityHint("Fills this set")
                .disabled(isLogged)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(font)
                .foregroundStyle(.secondary)
                .lineLimit(lineLimit)
                .frame(minHeight: cellHeight)
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
