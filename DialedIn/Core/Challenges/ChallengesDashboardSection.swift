//
//  ChallengesDashboardSection.swift
//  DialedIn
//
//  "Challenges" under the Dashboard's leaderboard: one card per running challenge, with days left,
//  the reader's ring and the top three.
//

import SwiftUI

struct ChallengesDashboardSection: View {

    let cards: [DashboardPresenter.ChallengeCard]
    let currentUserId: String?
    let onCardPressed: (DashboardPresenter.ChallengeCard) -> Void
    let onCreatePressed: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Challenges")
                    .font(.sectionTitle)
                Spacer()
                Button("New", systemImage: Symbol.add) {
                    onCreatePressed()
                }
                .font(.rowDetail)
                .accessibilityLabel("New challenge")
            }
            if cards.isEmpty {
                Text("Challenge your circle to train a set number of times.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
            ForEach(cards) { card in
                cardView(card)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.s)
    }

    private func cardView(_ card: DashboardPresenter.ChallengeCard) -> some View {
        Button {
            onCardPressed(card)
        } label: {
            HStack(spacing: Spacing.l) {
                ChallengeRing(sessions: card.mySessions, target: card.challenge.targetSessions)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(card.challenge.title)
                        .font(.rowTitle)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(card.daysLeft == 1 ? String(localized: "1 day left") : String(localized: "\(card.daysLeft) days left"))
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                    topThree(card)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.label)
                    .foregroundStyle(.tertiary)
            }
            .padding(Spacing.m)
            .cardSurface()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the standings")
    }

    private func topThree(_ card: DashboardPresenter.ChallengeCard) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            ForEach(Array(card.topThree.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: Spacing.xs) {
                    UserAvatarView(imageUrl: entry.imageUrl, size: 20)
                    Text("\(index + 1). \(entry.userId == currentUserId ? "You" : entry.name) \(entry.sessions)")
                        .font(.label.monospacedDigit())
                        .lineLimit(1)
                }
            }
        }
    }
}

#Preview {
    ChallengesDashboardSection(
        cards: [
            DashboardPresenter.ChallengeCard(
                challenge: .mock,
                daysLeft: 12,
                mySessions: 5,
                topThree: [
                    ChallengeStandings.Entry(userId: "a", name: "Alice", imageUrl: nil, sessions: 7, isComplete: false),
                    ChallengeStandings.Entry(userId: "b", name: "Bob", imageUrl: nil, sessions: 5, isComplete: false)
                ]
            )
        ],
        currentUserId: "b",
        onCardPressed: { _ in },
        onCreatePressed: { }
    )
}
