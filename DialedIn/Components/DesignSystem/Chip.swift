//
//  Chip.swift
//  DialedIn
//

import SwiftUI

/// A capsule label: a tag, a filter or a badge.
///
/// Unselected it is `tint` on `tintedSurface(tint)`. Selected it is a solid `tint` with `onAccent`
/// text and the `.isSelected` trait. Leave `tint` as the accent for anything selectable, and pass
/// a data colour only for a chip that carries that data's meaning.
struct Chip: View {

    private let text: Text
    var systemImage: String?
    var tint: Color = .accentColor
    var isSelected: Bool = false

    init(_ titleKey: LocalizedStringKey, systemImage: String? = nil, tint: Color = .accentColor, isSelected: Bool = false) {
        self.init(text: Text(titleKey), systemImage: systemImage, tint: tint, isSelected: isSelected)
    }

    @_disfavoredOverload
    init<S: StringProtocol>(_ text: S, systemImage: String? = nil, tint: Color = .accentColor, isSelected: Bool = false) {
        self.init(text: Text(text), systemImage: systemImage, tint: tint, isSelected: isSelected)
    }

    private init(text: Text, systemImage: String?, tint: Color, isSelected: Bool) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
        self.isSelected = isSelected
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            text
        }
        .chipStyle(tint: tint, filled: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension View {
    /// The capsule `Chip` draws. `filled` is the selected look: solid `tint`, `onAccent` text.
    func chipStyle(tint: Color, filled: Bool) -> some View {
        font(.label)
            .fontWeight(.semibold)
            .foregroundStyle(filled ? Color.onAccent : tint)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(filled ? tint : Color.tintedSurface(tint), in: .capsule)
    }
}

extension View {
    /// Pads a small button label's hit area out to the 44 x 44 pt minimum without changing how it
    /// looks or how much room it takes. Apply it to the label, inside the `Button`: outside, the
    /// area is not part of the button and does not respond.
    ///
    /// The hit area is an invisible background that overhangs the label, so it never enlarges a
    /// `.glass` capsule drawn around the label or pushes neighbouring views apart. It used to be a
    /// 44 pt frame on the label itself, which inside a glass button became the visible shape.
    /// A clipping container (a `ScrollView`, a `List` row) still bounds the overhang, so give that
    /// container the 44 pt height when the label sits at its edge.
    func tapTarget() -> some View {
        background {
            Color.clear
                .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
                .contentShape(.rect)
        }
    }

    /// A chip is about 20 pt tall. Inside a button, this pads its hit area out to the minimum.
    ///
    /// Unlike `tapTarget()` it takes the 44 pt height in the layout: chips sit in horizontal
    /// scroll views, which would clip a hit area that only overhangs. A chip draws its own capsule,
    /// so the taller frame stays invisible.
    func chipTapTarget() -> some View {
        frame(minHeight: ControlSize.row)
            .contentShape(.rect)
    }
}

// MARK: - Preview

private struct ChipPreview: View {
    var body: some View {
        List {
            Section("Accent") {
                HStack {
                    Chip("All")
                    Chip("Selected", isSelected: true)
                    Chip("Filter", systemImage: Symbol.filter)
                }
            }
            Section("Data tints") {
                HStack {
                    Chip("Protein", tint: .protein)
                    Chip("Carbs", tint: .carbs)
                    Chip("Fat", tint: .fat)
                }
                HStack {
                    Chip("Warm-up", tint: .warmup)
                    Chip("Superset", tint: .superset)
                    Chip("PR", systemImage: Symbol.personalRecord, tint: .personalRecord)
                }
                HStack {
                    Chip("Selected", tint: .protein, isSelected: true)
                    Chip("Danger", systemImage: Symbol.warning, tint: .danger)
                }
            }
        }
    }
}

#Preview("Chip, light") {
    ChipPreview().preferredColorScheme(.light)
}

#Preview("Chip, dark") {
    ChipPreview().preferredColorScheme(.dark)
}

#Preview("Chip, accessibility size") {
    ChipPreview().dynamicTypeSize(.accessibility3)
}
