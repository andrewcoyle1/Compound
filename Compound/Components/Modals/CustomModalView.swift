//
//  CustomModalView.swift
//  Compound
//
//  Created by Andrew Coyle on 02/10/2025.
//

import SwiftUI

struct CustomModalView: View {

    var title: String = "Title"
    var subtitle: String? = "This is a subtitle"
    var primaryButtonTitle: String = "Yes"
    var primaryButtonAction: () -> Void = { }
    var secondaryButtonTitle: String = "No"
    var secondaryButtonAction: () -> Void = { }
    // Optional middle content area for custom views (e.g., pickers)
    var middleContent: AnyView?

    var body: some View {
        // At the largest text sizes the card is taller than the screen, so it scrolls then.
        ViewThatFits(in: .vertical) {
            card
            ScrollView { card }
        }
        .padding(Spacing.xxl)
    }

    private var card: some View {
        VStack(spacing: Spacing.xl) {
            VStack(spacing: Spacing.m) {
                Text(title)
                    .font(.title)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                }

            }
            .padding(Spacing.m)

            if let middleContent {
                middleContent
            }

            VStack(spacing: Spacing.s) {
                Button {
                    primaryButtonAction()
                } label: {
                    // Callers pass plain strings ("Yes", "Cancel"), which `Text` shows verbatim.
                    // As a key they are looked up, and one already translated falls through.
                    Text(LocalizedStringKey(primaryButtonTitle))
                        .padding(.vertical, Spacing.m)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.onAccent)
                }
                .buttonStyle(.glassProminent)

                // A caller with one action passes an empty title, which drew an invisible button.
                if !secondaryButtonTitle.isEmpty {
                    Text(LocalizedStringKey(secondaryButtonTitle))
                        .font(.sectionTitle)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, Spacing.m)
                        .frame(maxWidth: .infinity)
                        .tappableBackground()
                        .anyButton(.plain) {
                            secondaryButtonAction()
                        }
                }
            }
        }
        .multilineTextAlignment(.center)
        .padding(Spacing.l)
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.xl, style: .continuous))
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        CustomModalView(
            title: "Are you enjoying Compound?",
            subtitle: "We'd love to hear your feedback!",
            primaryButtonTitle: "Yes",
            primaryButtonAction: { },
            secondaryButtonTitle: "Not now",
            secondaryButtonAction: { }
        )
    }
}
