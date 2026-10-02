//
//  CircleLeaderboardView.swift
//  Compound
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
    @ScaledMetric(relativeTo: .subheadline) private var rankWidth: CGFloat = 20

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 0) {
                ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                    row(standing, rank: index + 1)
                }
            }
        } label: {
            Text("This Week")
                .font(.sectionTitle)
        }
        .padding()
        .cardSurface()
        .padding(.horizontal)
        .padding(.bottom, Spacing.m)
    }

    private func row(_ standing: CircleWeek.Standing, rank: Int) -> some View {
        let isOwn = standing.id == currentUserId
        return Button {
            onRowPressed(standing)
        } label: {
            HStack(spacing: Spacing.m) {
                Text(rank, format: .number)
                    .font(.rowDetail.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: rankWidth)
                UserAvatarView(imageUrl: standing.user.profileImageNameCalculated, size: 32)
                Text(isOwn ? String(localized: "You") : standing.name)
                    .font(.rowDetail)
                    .fontWeight(isOwn ? .semibold : .regular)
                    .lineLimit(1)
                if rank == 1, standing.sessions > 0 {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.personalRecord)
                        .accessibilityLabel("Leader")
                }
                Spacer(minLength: 0)
                Text("\(standing.sessions)/\(standing.goal)")
                    .font(.metricSmall)
                    .foregroundStyle(standing.sessions >= standing.goal ? .success : .secondary)
            }
            .padding(Spacing.s)
            .background(isOwn ? Color.tintedSurface(.accentColor) : .clear, in: .rect(cornerRadius: Radius.m, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rank). \(isOwn ? String(localized: "You") : standing.name), \(standing.sessions) of \(standing.goal) sessions")
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
