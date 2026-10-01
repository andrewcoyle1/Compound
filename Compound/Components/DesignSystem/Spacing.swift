//
//  Spacing.swift
//  Compound
//

import SwiftUI

// The contract fixes these as T-shirt sizes (`Spacing.s`, `Radius.xl`), shorter than
// identifier_name's three-character minimum.
// swiftlint:disable identifier_name

/// Layout metrics. Use a token wherever a number would otherwise be written.
///
/// - Plain `.padding()` and `.padding(.horizontal)` stay: they are the system default (16).
/// - Off-grid values (1, 3, 5, 6, 10, 14) round to the nearest token.
/// - `xs`/`s` separate a label from its value or an icon from its text; `m` separates rows inside a
///   card; `l` is the card's inner padding and the gap between cards; `xl`/`xxl` separate sections.
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

/// Corner radii. Every rounded shape is continuous:
/// `.rect(cornerRadius: Radius.l, style: .continuous)` or
/// `RoundedRectangle(cornerRadius: Radius.l, style: .continuous)`. Never `.cornerRadius(_:)`.
/// Capsules and circles stay as they are.
///
/// | Radius | Use |
/// |---|---|
/// | `xl` | Full-width cards |
/// | `l`  | Grid tiles |
/// | `m`  | Inline panels |
/// | `s`  | Thumbnails and small controls |
enum Radius {
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}

// swiftlint:enable identifier_name

/// Fixed control dimensions. `row` is the minimum tap target; `thumbnail` the list-row image;
/// `icon` a leading row glyph's frame (its glyph size comes from `.iconSize(_:)`).
enum ControlSize {
    static let icon: CGFloat = 24
    static let thumbnail: CGFloat = 40
    static let row: CGFloat = 44
}

/// Chart plot heights. `compact` inside a card, `regular` on a detail screen.
enum ChartHeight {
    static let compact: CGFloat = 150
    static let regular: CGFloat = 200
}

/// The widest a screen's scroll content grows on iPad and Mac. Wider screens centre it, so rows,
/// cards and charts keep phone-like proportions. Set once at the root; see `readableContentWidth`.
enum ContentWidth {
    static let readable: CGFloat = 700
    /// A `Dashboard`'s column pair, wider than `readable` because each column is phone-width.
    static let dashboard: CGFloat = 1100
    /// The narrowest a `Dashboard` goes to two columns: two phone-width cards side by side.
    static let twoColumns: CGFloat = 740
}

#Preview("Spacing and radius") {
    let spacings: [(String, CGFloat)] = [("xxs", Spacing.xxs), ("xs", Spacing.xs), ("s", Spacing.s), ("m", Spacing.m), ("l", Spacing.l), ("xl", Spacing.xl), ("xxl", Spacing.xxl)]
    let radii: [(String, CGFloat)] = [("s", Radius.s), ("m", Radius.m), ("l", Radius.l), ("xl", Radius.xl)]
    return List {
        Section("Spacing") {
            ForEach(spacings, id: \.0) { name, value in
                HStack {
                    Text(name).font(.label).frame(width: 40, alignment: .leading)
                    Rectangle().fill(.tint).frame(width: value * 4, height: Spacing.s)
                    Text(value.formatted()).font(.label).foregroundStyle(.secondary)
                }
            }
        }
        Section("Radius") {
            HStack(spacing: Spacing.m) {
                ForEach(radii, id: \.0) { name, value in
                    RoundedRectangle(cornerRadius: value, style: .continuous)
                        .fill(Color.tintedSurface(.accentColor))
                        .frame(width: 64, height: 64)
                        .overlay { Text(name).font(.label) }
                }
            }
        }
    }
}
