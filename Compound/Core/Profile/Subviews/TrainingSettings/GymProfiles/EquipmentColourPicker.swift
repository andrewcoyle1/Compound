//
//  EquipmentColourPicker.swift
//  Compound
//

import SwiftUI

/// The swatch row the Add Band and Add Free Weight sheets use to colour-code a band or plate.
/// Each swatch is a button named after its colour and carries `.isSelected`, so VoiceOver can
/// tell them apart; they used to be unlabelled circles.
struct EquipmentColourPicker: View {
    let title: LocalizedStringKey
    let colours: [Color]
    let selectedColour: Color?
    let onSelect: (Color) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(.sectionTitle)
            HStack {
                ForEach(colours, id: \.self) { colour in
                    let isSelected = colour == selectedColour
                    Button {
                        onSelect(colour)
                    } label: {
                        Circle()
                            .fill(Color.tintedSurface(colour))
                            .overlay {
                                Circle()
                                    .stroke(isSelected ? colour : Color.clear, lineWidth: 4)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Self.name(of: colour))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal)
        }
    }

    /// The names of the swatches both presenters offer. `.primary` draws black in light mode and
    /// white in dark, so it is called by what it is rather than by either.
    static func name(of colour: Color) -> Text {
        switch colour {
        case .primary: return Text("Default")
        case .red: return Text("Red")
        case .orange: return Text("Orange")
        case .yellow: return Text("Yellow")
        case .green: return Text("Green")
        case .blue: return Text("Blue")
        case .purple: return Text("Purple")
        default: return Text("Color")
        }
    }
}
