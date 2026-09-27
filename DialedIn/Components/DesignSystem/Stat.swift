//
//  Stat.swift
//  DialedIn
//

import SwiftUI

/// A value above its label, with an optional leading symbol.
///
/// `value` and `label` are shown verbatim: pass `String(localized:)` for the label. VoiceOver reads
/// the pair as one element, "label, value".
struct Stat: View {

    enum Size {
        case small, medium, large

        var valueFont: Font {
            switch self {
            case .small: return .metricSmall
            case .medium: return .metric
            case .large: return .metricLarge
            }
        }
    }

    let value: String
    let label: String
    var systemImage: String?
    var size: Size = .medium
    var alignment: HorizontalAlignment = .leading
    /// Colours the symbol. Without it the symbol is `.secondary`.
    var tint: Color?

    var body: some View {
        VStack(alignment: alignment, spacing: Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint ?? .secondary)
                }
                Text(value)
            }
            .font(size.valueFont)
            Text(label)
                .font(.label)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

extension Stat {
    /// A `Stat` on its own tile: padded, full width, on `.cardSurface(.tile)`, or
    /// `.cardSurface(.tinted(tint))` when a tint is passed.
    static func tile(
        value: String,
        label: String,
        systemImage: String? = nil,
        size: Size = .medium,
        alignment: HorizontalAlignment = .leading,
        tint: Color? = nil
    ) -> some View {
        Stat(value: value, label: label, systemImage: systemImage, size: size, alignment: alignment, tint: tint)
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
            .cardSurface(tint.map { .tinted($0) } ?? .tile)
    }
}

// MARK: - Preview

private struct StatPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                HStack(alignment: .top, spacing: Spacing.xl) {
                    Stat(value: "8", label: "Exercises", size: .small)
                    Stat(value: "82.5 kg", label: "Weight", size: .medium)
                    Stat(value: "1,850", label: "Calories", size: .large)
                }
                HStack(alignment: .top, spacing: Spacing.xl) {
                    Stat(value: "12", label: "Streak", systemImage: Symbol.streak, size: .small, tint: .warning)
                    Stat(value: "54:12", label: "Duration", systemImage: Symbol.duration, alignment: .center)
                    Stat(value: "4,210", label: "Volume", systemImage: Symbol.volume, size: .large, alignment: .trailing)
                }
                HStack(spacing: Spacing.m) {
                    Stat.tile(value: "142 g", label: "Protein", tint: .protein)
                    Stat.tile(value: "210 g", label: "Carbs", tint: .carbs)
                    Stat.tile(value: "61 g", label: "Fat", tint: .fat)
                }
                HStack(spacing: Spacing.m) {
                    Stat.tile(value: "8,402", label: "Steps", systemImage: Symbol.steps, size: .small)
                    Stat.tile(value: "3", label: "Workouts", systemImage: Symbol.workout, alignment: .center, tint: Color.Metric.workouts)
                }
            }
            .padding()
        }
        .background(Color.canvas)
    }
}

#Preview("Stat, light") {
    StatPreview().preferredColorScheme(.light)
}

#Preview("Stat, dark") {
    StatPreview().preferredColorScheme(.dark)
}

#Preview("Stat, accessibility size") {
    StatPreview().dynamicTypeSize(.accessibility3)
}
