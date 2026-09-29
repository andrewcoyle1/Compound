//
//  CircleLeaderboardView.swift
//  DialedIn
//
//  "This week" under the circle strip: everyone ranked by sessions this week. Collapsed by default
//  so it does not push the feed down; the strip's rings already say most of it at a glance.
//

import SwiftUI

struct CircleLeaderboardView: View {

    let standings: [CircleWeek.Standing]
    let currentUserId: String?
    let onRowPressed: (CircleWeek.Standing) -> Void

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 0) {
                ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                    row(standing, rank: index + 1)
                }
            }
        } label: {
            Text("This week")
                .font(.headline)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private func row(_ standing: CircleWeek.Standing, rank: Int) -> some View {
        let isOwn = standing.id == currentUserId
        return Button {
            onRowPressed(standing)
        } label: {
            HStack(spacing: 12) {
                Text("\(rank)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                UserAvatarView(imageUrl: standing.user.profileImageNameCalculated, size: 32)
                Text(isOwn ? "You" : standing.name)
                    .font(.subheadline.weight(isOwn ? .semibold : .regular))
                    .lineLimit(1)
                if rank == 1, standing.sessions > 0 {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Leader")
                }
                Spacer(minLength: 0)
                Text("\(standing.sessions)/\(standing.goal)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(standing.sessions >= standing.goal ? .green : .secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(isOwn ? Color.accentColor.opacity(0.12) : .clear, in: .rect(cornerRadius: 12))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rank). \(isOwn ? "You" : standing.name), \(standing.sessions) of \(standing.goal) sessions")
        .accessibilityHint("Opens their profile")
    }
}

#Preview {
    CircleLeaderboardView(
        standings: [
            CircleWeek.Standing(user: UserModel(userId: "b", submittedFirstName: "Sam"), sessions: 4, volumeKg: 9000, goal: 4),
            CircleWeek.Standing(user: .mock, sessions: 2, volumeKg: 5000, goal: 3)
        ],
        currentUserId: UserModel.mock.userId,
        onRowPressed: { _ in }
    )
}
