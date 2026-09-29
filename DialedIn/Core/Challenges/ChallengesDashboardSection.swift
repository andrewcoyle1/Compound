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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Challenges")
                    .font(.headline)
                Spacer()
                Button("New", systemImage: "plus") {
                    onCreatePressed()
                }
                .font(.subheadline)
                .accessibilityLabel("New challenge")
            }
            if cards.isEmpty {
                Text("Challenge your circle to train a set number of times.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(cards) { card in
                cardView(card)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func cardView(_ card: DashboardPresenter.ChallengeCard) -> some View {
        Button {
            onCardPressed(card)
        } label: {
            HStack(spacing: 16) {
                ChallengeRing(sessions: card.mySessions, target: card.challenge.targetSessions)
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.challenge.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(card.daysLeft == 1 ? String(localized: "1 day left") : String(localized: "\(card.daysLeft) days left"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    topThree(card)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the standings")
    }

    private func topThree(_ card: DashboardPresenter.ChallengeCard) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(card.topThree.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 4) {
                    UserAvatarView(imageUrl: entry.imageUrl, size: 20)
                    Text("\(index + 1). \(entry.userId == currentUserId ? "You" : entry.name) \(entry.sessions)")
                        .font(.caption2.monospacedDigit())
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
