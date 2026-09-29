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

    @ScaledMetric(relativeTo: .body) private var swatchSide = ControlSize.row
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Fewer, larger swatches at the accessibility sizes, where six across no longer fit.
    private func columns(_ count: Int) -> [GridItem] {
        Array(repeating: GridItem(), count: dynamicTypeSize.isAccessibilitySize ? min(count, 4) : count)
    }

    var body: some View {
        VStack(spacing: Spacing.l) {
            LazyVGrid(columns: columns(colours.count), spacing: Spacing.s) {
                ForEach(colours, id: \.self) { colour in
                    swatch(systemImage: selectedIcon, colour: colour, isSelected: colour == selectedColour)
                        .anyButton {
                            onColourPressed(colour)
                        }
                        .accessibilityLabel(Self.name(of: colour))
                        .accessibilityAddTraits(colour == selectedColour ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal)

            Divider()

            LazyVGrid(columns: columns(6), spacing: Spacing.s) {
                ForEach(icons, id: \.self) { icon in
                    swatch(systemImage: icon, colour: selectedColour, isSelected: icon == selectedIcon)
                        .anyButton {
                            onIconPressed(icon)
                        }
                        .accessibilityLabel(Self.name(of: icon))
                        .accessibilityAddTraits(icon == selectedIcon ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal)
        }
    }

    /// VoiceOver used to read `Color.description` and the SF Symbol's name.
    static func name(of colour: Color) -> String {
        switch colour {
        case .primary: String(localized: "Default")
        case .red: String(localized: "Red")
        case .orange: String(localized: "Orange")
        case .yellow: String(localized: "Yellow")
        case .green: String(localized: "Green")
        case .blue: String(localized: "Blue")
        case .purple: String(localized: "Purple")
        default: String(localized: "Color")
        }
    }

    static func name(of icon: String) -> String {
        switch icon {
        case "flag.pattern.checkered": String(localized: "Checkered Flag")
        case "arcade.stick": String(localized: "Joystick")
        case "gamecontroller": String(localized: "Game Controller")
        case "figure.walk": String(localized: "Walking Figure")
        case "airplane.up.right": String(localized: "Airplane")
        case "sailboat.fill": String(localized: "Sailboat")
        case "gauge.with.dots.needle.bottom.100percent": String(localized: "Gauge")
        default: String(localized: "Icon")
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
