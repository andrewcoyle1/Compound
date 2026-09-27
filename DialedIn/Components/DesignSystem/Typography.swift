//
//  Typography.swift
//  DialedIn
//

import SwiftUI

/// The type ramp. Every token is built on a text style, so it scales with Dynamic Type.
///
/// | Token | Use |
/// |---|---|
/// | `display` | Hero numbers, onboarding headings |
/// | `metricLarge` | A card's headline number |
/// | `metric` | A stat value |
/// | `metricSmall` | A compact stat, a row's trailing value |
/// | `sectionTitle` | Card and section titles |
/// | `rowTitle` | List row title (17 pt at the default size) |
/// | `rowDetail` | Row subtitle, with `.secondary` (15 pt at the default size) |
/// | `label` | Stat labels and chips, with `.secondary` |
///
/// Change weight through the token or `.fontWeight(_:)`, never `.bold()` on top of a token.
/// Symbols take their size from `.iconSize(_:)`, not `.font(.system(size:))`, which is allowed
/// only in share cards and the widget.
extension Font {
    static let display = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let metricLarge = Font.system(.title, design: .rounded, weight: .semibold).monospacedDigit()
    static let metric = Font.system(.title3, design: .rounded, weight: .semibold).monospacedDigit()
    static let metricSmall = Font.system(.subheadline, design: .rounded, weight: .semibold).monospacedDigit()
    static let sectionTitle = Font.headline
    static let rowTitle = Font.body
    static let rowDetail = Font.subheadline
    static let label = Font.caption
}

/// Symbol sizes at the default Dynamic Type size. `.iconSize(_:)` scales them with the user's
/// setting.
///
/// - `small` (17): inline with body text, row accessories.
/// - `medium` (24): a row's leading glyph, toolbar-sized glyphs.
/// - `large` (44): a card's feature glyph.
/// - `hero` (64): empty states and onboarding illustrations.
enum IconSize: CaseIterable {
    case small, medium, large, hero

    var points: CGFloat {
        switch self {
        case .small: return 17
        case .medium: return 24
        case .large: return 44
        case .hero: return 64
        }
    }
}

extension View {
    /// Sizes an SF Symbol (or any text) to `size`, scaled with Dynamic Type.
    func iconSize(_ size: IconSize) -> some View {
        modifier(IconSizeModifier(size: size))
    }
}

private struct IconSizeModifier: ViewModifier {
    @ScaledMetric private var points: CGFloat

    init(size: IconSize) {
        _points = ScaledMetric(wrappedValue: size.points, relativeTo: .body)
    }

    func body(content: Content) -> some View {
        content.font(.system(size: points))
    }
}

// MARK: - Preview

private struct TypographyPreview: View {
    var body: some View {
        List {
            Section("Type ramp") {
                Text("1,850").font(.display)
                Text("1,850 kcal").font(.metricLarge)
                Text("82.5 kg").font(.metric)
                Text("8 reps").font(.metricSmall)
                Text("Section title").font(.sectionTitle)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Row title").font(.rowTitle)
                    Text("Row detail").font(.rowDetail).foregroundStyle(.secondary)
                }
                Text("Label").font(.label).foregroundStyle(.secondary)
            }
            Section("Icon sizes") {
                HStack(alignment: .bottom, spacing: Spacing.l) {
                    ForEach(IconSize.allCases, id: \.self) { size in
                        Image(systemName: Symbol.workout).iconSize(size)
                    }
                }
                .foregroundStyle(.tint)
            }
        }
    }
}

#Preview("Typography, light") {
    TypographyPreview().preferredColorScheme(.light)
}

#Preview("Typography, dark") {
    TypographyPreview().preferredColorScheme(.dark)
}

#Preview("Typography, accessibility size") {
    TypographyPreview().dynamicTypeSize(.accessibility3)
}
