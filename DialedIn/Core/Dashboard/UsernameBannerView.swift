//
//  UsernameBannerView.swift
//  DialedIn
//
//  Onboarding has no username step; this nudges from the Dashboard instead, until the user picks
//  one or dismisses it. Dismissal is per device, which is all a one-time prompt needs.
//

import SwiftUI

struct UsernameBannerView: View {

    let onPickPressed: () -> Void

    @AppStorage("hasDismissedUsernameBanner") private var isDismissed = false

    var body: some View {
        if !isDismissed {
            Section {
                // Two plain buttons rather than a tappable row holding a button: in a List row the
                // row's button would swallow the dismiss tap.
                HStack(spacing: 12) {
                    Button(action: onPickPressed) {
                        HStack(spacing: 12) {
                            Image(systemName: "at")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.tint)
                            Text("Pick a username so friends can find you")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button {
                        isDismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                }
            }
        }
    }
}

#Preview {
    List {
        UsernameBannerView(onPickPressed: { })
    }
}
