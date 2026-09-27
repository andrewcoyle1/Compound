//
//  CustomModalView.swift
//  DialedIn
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
        VStack(spacing: Spacing.xl) {
            VStack(spacing: Spacing.m) {
                Text(title)
                    .font(.title)
                    .fontWeight(.semibold)
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
                    Text(primaryButtonTitle)
                        .padding(.vertical, Spacing.m)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.onAccent)
                }
                .buttonStyle(.glassProminent)

                Text(secondaryButtonTitle)
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
        .multilineTextAlignment(.center)
        .padding(Spacing.l)
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.xl, style: .continuous))
        .padding(Spacing.xxl)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        CustomModalView(
            title: "Are you enjoying Dialed?",
            subtitle: "We'd love to hear your feedback!",
            primaryButtonTitle: "Yes",
            primaryButtonAction: { },
            secondaryButtonTitle: "Not now",
            secondaryButtonAction: { }
        )
    }
}
