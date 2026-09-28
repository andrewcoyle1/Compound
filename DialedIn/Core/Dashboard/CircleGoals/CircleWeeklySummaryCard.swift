//
//  CircleWeeklySummaryCard.swift
//  DialedIn
//
//  Monday's one-line recap of last week at the top of the feed, dismissible for the week.
//

import SwiftUI

struct CircleWeeklySummaryCard: View {

    let summary: CircleWeek.Summary
    let onDismissPressed: () -> Void

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: Symbol.streak)
                .iconSize(.medium)
                .foregroundStyle(.success)
                .accessibilityHidden(true)
            Text(summary.text)
                .font(.rowDetail)
                .fontWeight(.medium)
            Spacer(minLength: 0)
            Button(role: .close, action: onDismissPressed)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Dismiss last week's summary")
        }
        .padding()
        .cardSurface()
        .padding(.horizontal)
        .padding(.bottom, Spacing.s)
    }
}

#Preview {
    CircleWeeklySummaryCard(
        summary: CircleWeek.Summary(weekId: "2026-W10", ownSessions: 3, ownGoal: 3, circleSessions: 11),
        onDismissPressed: { }
    )
}
