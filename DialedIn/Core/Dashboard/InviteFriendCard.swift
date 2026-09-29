//
//  InviteFriendCard.swift
//  DialedIn
//
//  The Dashboard's one-time nudge to invite someone, shown once the user has a few workouts in.
//

import SwiftUI

struct InviteFriendCard: View {

    @Environment(\.colorScheme) private var colorScheme

    let onPressed: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPressed) {
                HStack(spacing: 12) {
                    Image(systemName: "person.badge.plus")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invite a friend")
                            .font(.subheadline.weight(.medium))
                        Text("Training's easier with someone keeping you honest.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding()
        .background(colorScheme.backgroundPrimary, in: .rect(cornerRadius: 24))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

#Preview {
    InviteFriendCard(onPressed: { }, onDismiss: { })
}
