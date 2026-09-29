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
                HStack(spacing: Spacing.m) {
                    Button(action: onPickPressed) {
                        HStack(spacing: Spacing.m) {
                            Image(systemName: "at")
                                .iconSize(.medium)
                                .fontWeight(.semibold)
                                .foregroundStyle(.tint)
                            Text("Pick a username so friends can find you")
                                .font(.rowDetail)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button(role: .close) {
                        isDismissed = true
                    }
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .contentShape(.rect)
                    .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
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
