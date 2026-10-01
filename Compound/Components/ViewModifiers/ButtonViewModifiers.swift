//
//  ButtonViewModifiers.swift
//  Compound
//
//  Created by Andrew Coyle on 10/8/24.
//

import SwiftUI

struct HighlightButtonStyle: ButtonStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                configuration.isPressed ? Color.accentColor.opacity(0.4) : Color.accentColor.opacity(0)
            }
            .reducedMotionAnimation(.standard, value: configuration.isPressed)
    }
}

struct PressableButtonStyle: ButtonStyle {

    /// With Reduce Motion on, a pressed card dims instead of shrinking.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.6 : 1)
            .reducedMotionAnimation(.standard, value: configuration.isPressed)
    }
}

enum ButtonStyleOption {
    case press, highlight, plain
}

extension View {
    
    @ViewBuilder
    func anyButton(_ option: ButtonStyleOption = .plain, action: @escaping () -> Void) -> some View {
        switch option {
        case .press:
            self.pressableButton(action: action)
        case .highlight:
            self.highlightButton(action: action)
        case .plain:
            self.plainButton(action: action)
        }
    }
    
    private func plainButton(action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            self
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func highlightButton(action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            self
        }
        .buttonStyle(HighlightButtonStyle())
    }
    
    private func pressableButton(action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            self
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    VStack {
        Text(
            "Hello, world!"
        )
        .padding()
        .frame(maxWidth: .infinity)
        .tappableBackground()
        .anyButton(
            .highlight,
            action: {

            }
        )
        .padding()

        Text("Hello, world!")
            .anyButton(.press, action: { })
            .padding()

        Text("Hello, world!")
            .anyButton(action: { })
            .padding()
    }
}
