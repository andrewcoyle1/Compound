//
//  ProgramColourIconGrid.swift
//  DialedIn
//

import SwiftUI

/// The colour row and icon grid a program is styled with, shared by the create flow's icon step
/// and Program Settings' colour and icon editor, which each carried a copy.
///
/// The swatches draw in the program's own colours, which are user data. The ring around the
/// chosen one is the accent, because it marks selection.
struct ProgramColourIconGrid: View {
    let colours: [Color]
    let icons: [String]
    let selectedColour: Color
    let selectedIcon: String
    let onColourPressed: (Color) -> Void
    let onIconPressed: (String) -> Void

    @ScaledMetric(relativeTo: .body) private var swatchSide = ControlSize.thumbnail

    var body: some View {
        VStack(spacing: Spacing.l) {
            HStack {
                ForEach(colours, id: \.self) { colour in
                    swatch(systemImage: selectedIcon, colour: colour, isSelected: colour == selectedColour)
                        .anyButton {
                            onColourPressed(colour)
                        }
                        .accessibilityLabel(colour.description.capitalized)
                        .accessibilityAddTraits(colour == selectedColour ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal)

            Divider()

            LazyVGrid(columns: Array(repeating: GridItem(), count: 6), spacing: Spacing.s) {
                ForEach(icons, id: \.self) { icon in
                    swatch(systemImage: icon, colour: selectedColour, isSelected: icon == selectedIcon)
                        .anyButton {
                            onIconPressed(icon)
                        }
                        .accessibilityLabel(icon)
                        .accessibilityAddTraits(icon == selectedIcon ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal)
        }
    }

    private func swatch(systemImage: String, colour: Color, isSelected: Bool) -> some View {
        Image(systemName: systemImage)
            .foregroundStyle(colour)
            .frame(width: swatchSide, height: swatchSide)
            .background(Color.tintedSurface(colour), in: .circle)
            .overlay {
                Circle()
                    .stroke(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 3)
            }
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProgramColourIconGrid(
        colours: [.red, .orange, .green, .blue, .purple],
        icons: ["flame", "bolt", "star", "heart", "leaf", "flag", "figure.run"],
        selectedColour: .green,
        selectedIcon: "bolt",
        onColourPressed: { _ in },
        onIconPressed: { _ in }
    )
}
