//
//  SetTableHeadings.swift
//  Compound
//
//  The column headings over the set rows.
//

import SwiftUI

/// Set (or a superset member's label), the Last/Auto switch, a heading per field at the rows'
/// widths, and Done. Stacked at accessibility sizes, as the rows are, where Set and Done need no
/// heading.
struct SetTableHeadings<FieldHeading: View>: View {

    var setLabel: String?
    let fields: [SetKeyboardField]
    @Binding var showsAuto: Bool
    @ViewBuilder let heading: (SetKeyboardField) -> FieldHeading

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if let setLabel {
                        Text(setLabel)
                    }
                    LastAutoToggle(showsAuto: $showsAuto)
                    fieldHeadings
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(setLabel ?? String(localized: "Set"))
                        .frame(width: SetTable.setColumnWidth, alignment: .center)
                    Spacer()
                    LastAutoToggle(showsAuto: $showsAuto)
                    Spacer()
                    fieldHeadings
                    Spacer()
                    Text("Done")
                        .frame(width: SetTable.doneColumnWidth, alignment: .center)
                }
                // No line limit and no shrinking: Caption 2 is already the 11 pt floor, so a
                // heading too long for its column wraps instead.
                .multilineTextAlignment(.center)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var fieldHeadings: some View {
        HStack(spacing: Spacing.s) {
            ForEach(fields, id: \.self) { field in
                heading(field)
                    .setColumn(width: field.columnWidth(in: fields), stretches: dynamicTypeSize.isAccessibilitySize)
            }
        }
    }
}

/// The Last column's heading, which switches it between last session and smart progression.
struct LastAutoToggle: View {

    @Binding var showsAuto: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button {
            showsAuto.toggle()
        } label: {
            // A chip inside a real 44 pt frame, so the column stays narrow and the tap target full.
            // A one-word heading cannot wrap and must not shrink below 11 pt, so where the column
            // is too narrow for the symbol as well, the chip drops it.
            ViewThatFits(in: .horizontal) {
                chip(showsSymbol: true).fixedSize()
                chip(showsSymbol: false).fixedSize()
            }
            .frame(minHeight: ControlSize.row)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Switches between last session and smart progression")
        .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : SetTable.previousColumnWidth, alignment: .center)
    }

    /// An `HStack` rather than a `Label`: in a list a label sets aside an icon column as wide as a
    /// row's, which left the word no room.
    private func chip(showsSymbol: Bool) -> some View {
        HStack(spacing: Spacing.xxs) {
            if showsSymbol {
                Image(systemName: showsAuto ? Symbol.smartProgression : Symbol.history)
                    .accessibilityHidden(true)
            }
            if showsAuto {
                Text("Auto")
            } else {
                Text("Last")
            }
        }
        .lineLimit(1)
        .chipStyle(tint: .secondary, filled: false)
    }
}
