//
//  Card.swift
//  Compound
//

import SwiftUI

/// The fill and corner radius of a card surface.
///
/// | Style | Fill | Radius | Use |
/// |---|---|---|---|
/// | `card` | `surface` | `Radius.xl` | Full-width cards |
/// | `tile` | `surface` | `Radius.l` | Grid tiles |
/// | `tinted(c)` | `tintedSurface(c)` | `Radius.l` | A tile that carries a data colour |
enum CardStyle {
    case card
    case tile
    case tinted(Color)

    var fill: Color {
        switch self {
        case .card, .tile: return .surface
        case .tinted(let color): return .tintedSurface(color)
        }
    }

    var radius: CGFloat {
        switch self {
        case .card: return Radius.xl
        case .tile, .tinted: return Radius.l
        }
    }
}

extension View {
    /// Draws the card surface behind the view. Padding stays the caller's job.
    ///
    /// Also sets the container shape, so content inside can use `ConcentricRectangle`.
    func cardSurface(_ style: CardStyle = .card) -> some View {
        let shape = RoundedRectangle(cornerRadius: style.radius, style: .continuous)
        return background(style.fill, in: shape)
            .containerShape(shape)
    }
}

// MARK: - Preview

private struct CardPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                Text("Card")
                    .font(.sectionTitle)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()
                HStack(spacing: Spacing.l) {
                    Text("Tile")
                        .font(.sectionTitle)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardSurface(.tile)
                    Text("Tinted")
                        .font(.sectionTitle)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardSurface(.tinted(.protein))
                }
                ForEach([Color.calories, .carbs, .fat, Color.Metric.steps], id: \.self) { color in
                    Text("Tinted")
                        .font(.rowTitle)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardSurface(.tinted(color))
                }
            }
            .padding()
        }
        .background(Color.canvas)
    }
}

#Preview("Card, light") {
    CardPreview().preferredColorScheme(.light)
}

#Preview("Card, dark") {
    CardPreview().preferredColorScheme(.dark)
}

#Preview("Card, accessibility size") {
    CardPreview().dynamicTypeSize(.accessibility3)
}
