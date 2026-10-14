//
//  SetCircle.swift
//  Compound
//
//  The set's number in its circle, and the chip naming its kind.
//

import SwiftUI

/// The set's number, "W" for a warm-up or a superset's badge, in a circle of `tint`; `text` nil
/// is a drop or mini-set, which has no number of its own and shows where it hangs from.
///
/// Drawn rather than `.bordered`, which sizes the control to its text whatever its frame: a 44 pt
/// frame is what a thumb needs and the accessibility audit measures. The text stays the root, so
/// a menu with this as its label builds its accessibility element from it.
struct SetCircle: View {

    let text: String?
    let tint: Color
    var isEmphasised = false
    var isMuted = false
    let accessibilityLabel: String

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    /// Scaled with its text, so "12L" never clips at a larger size.
    @ScaledMetric(relativeTo: .caption) private var side: CGFloat = ControlSize.thumbnail - Spacing.xs

    var body: some View {
        // The primary colour on the tinted circle, for contrast: the tint is the circle's, and the
        // text says what it is.
        Group {
            if let text {
                Text(text)
            } else {
                Image(systemName: Symbol.subSet)
            }
        }
        .font(isEmphasised ? .label.weight(.semibold) : .label)
        .foregroundStyle(isMuted ? .secondary : .primary)
        // On the text, not a menu around it: the menu's button takes its accessibility from its label.
        .accessibilityLabel(accessibilityLabel)
        .frame(width: side, height: side)
        .background(Color.tintedSurface(tint), in: .circle)
        // Increase Contrast: the circle's edge in its full colour, where the fill alone is faint.
        .overlay {
            if colorSchemeContrast == .increased {
                Circle().strokeBorder(tint, lineWidth: 1)
            }
        }
        .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
        .contentShape(.circle)
    }
}

/// The set's kind under its circle: "Failure", or "Drop", "Mini", "Partials" on a sub-row. Under
/// rather than beside, so the columns keep the headings' widths. The text is in the primary colour
/// on its tint, for contrast, and hidden from VoiceOver, which hears the kind in the row's name.
struct SetKindChip: View {

    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .foregroundStyle(Color.primary)
            .lineLimit(1)
            .fixedSize()
            .chipStyle(tint: tint, filled: false)
            .accessibilityHidden(true)
    }
}
