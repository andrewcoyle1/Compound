//
//  CallToActionButton.swift
//  DialedIn
//
//  Created by Andrew Coyle on 24/02/2026.
//

import SwiftUI

/// A full-width flow button: `.glassProminent` for the primary action, `.glass` for a secondary
/// one. Pin it to the bottom of a screen with `.bottomCTA { … }`.
///
/// While `isLoading` is true the label is swapped for a spinner at the same height, the button
/// is disabled, and VoiceOver reads "Loading".
struct CallToActionButton<Content: View>: View {

    var isPrimaryAction: Bool = true
    var isLoading: Bool = false
    var action: () -> Void
    var label: () -> Content

    init(
        isPrimaryAction: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void,
        label: @escaping () -> Content
    ) {
        self.isPrimaryAction = isPrimaryAction
        self.isLoading = isLoading
        self.action = action
        self.label = label
    }

    var body: some View {
        ZStack {
            if isPrimaryAction {
                makeButton
                    .buttonStyle(.glassProminent)
            } else {
                makeButton
                    .buttonStyle(.glass)
            }
        }
        .padding(.horizontal)
        .disabled(isLoading)
        .accessibilityValue(isLoading ? Text("Loading") : Text(verbatim: ""))
    }

    private var makeButton: some View {
        Button {
            action()
        } label: {
            // The label stays in the layout while loading so the button keeps its height.
            label()
                .opacity(isLoading ? 0 : 1)
                .overlay {
                    if isLoading {
                        ProgressView()
                            .tint(isPrimaryAction ? Color.onAccent : Color.primary)
                    }
                }
                .foregroundStyle(isPrimaryAction ? Color.onAccent : Color.primary)
                .padding(.vertical, Spacing.m)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct CallToActionButtonPreview: View {
    @State private var isLoading = false

    var body: some View {
        List {
            ForEach(FoodModel.mocks) { mock in
                Text(mock.name)
            }
        }
        .bottomCTA {
            CallToActionButton(isLoading: isLoading) {
                isLoading.toggle()
            } label: {
                Text("Create & Add")
            }
            CallToActionButton(isPrimaryAction: false) {
                isLoading.toggle()
            } label: {
                Text("Create")
            }
        }
    }
}

#Preview("Light") {
    CallToActionButtonPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    CallToActionButtonPreview().preferredColorScheme(.dark)
}

#Preview("Accessibility size") {
    CallToActionButtonPreview().dynamicTypeSize(.accessibility3)
}
