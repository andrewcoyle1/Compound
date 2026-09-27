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
