//
//  CompoundStyle.swift
//  WorkoutSessionActivity
//
//  The design language (docs/specs/flutter/design-language.md) for the Live Activity and the
//  widgets. The colours are the asset catalog's: `AccentColor` is volt, a fill with black on it;
//  `AccentInk` is volt as text or a line (dark olive in light mode, darker with Increase
//  Contrast); `Surface` is a card's background.
//

import SwiftUI
import WidgetKit

extension Font {
    /// Barlow Condensed, bundled from app_ui, for big numbers only. It scales with the text size
    /// like the system style it stands in for.
    static func barlow(_ size: CGFloat, relativeTo style: Font.TextStyle, extraBold: Bool = true) -> Font {
        .custom(extraBold ? "BarlowCondensed-ExtraBold" : "BarlowCondensed-Bold", size: size, relativeTo: style)
    }
}

extension Text {
    /// A stat's label under its number: 12 pt semibold, all caps, tracked.
    func overline() -> some View {
        font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}

/// A filled circle symbol (a done tick, play) as a volt disc with a black glyph. When the system
/// tints the widget it draws the plain symbol instead, so the glyph stays cut out.
struct VoltDisc: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let systemName: String

    var body: some View {
        if renderingMode == .fullColor {
            Image(systemName: systemName)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.black, Color.accent)
        } else {
            Image(systemName: systemName)
                .widgetAccentable()
        }
    }
}

extension View {
    /// A volt-filled capsule button. With Increase Contrast in light mode it gains a 1 pt black
    /// outline, as volt alone is barely distinguishable from a light background (design language).
    func voltFill() -> some View {
        modifier(VoltFillOutline())
    }
}

private struct VoltFillOutline: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.accent)
            .overlay {
                if colorScheme == .light && contrast == .increased {
                    Capsule().strokeBorder(Color.black, lineWidth: 1)
                }
            }
    }
}
