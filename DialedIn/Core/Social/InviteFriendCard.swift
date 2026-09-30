//
//  InviteFriendCard.swift
//  DialedIn
//
//  The Dashboard's one-time nudge to invite someone, shown once the user has a few workouts in.
//

import SwiftUI

struct InviteFriendCard: View {

    let onPressed: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Spacing.m) {
            Button(action: onPressed) {
                HStack(spacing: Spacing.m) {
                    Image(systemName: "person.badge.plus")
                        .iconSize(.medium)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Invite a friend")
                            .font(.rowTitle)
                            .fontWeight(.medium)
                        Text("Training's easier with someone keeping you honest.")
                            .font(.rowDetail)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Button(role: .close, action: onDismiss)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
                .contentShape(.rect)
                .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
                .accessibilityLabel("Dismiss")
        }
        .padding()
        .cardSurface()
        .padding(.horizontal)
        .padding(.bottom, Spacing.s)
    }
}

#Preview {
    InviteFriendCard(onPressed: { }, onDismiss: { })
}
