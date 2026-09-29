//
//  CircleWeeklySummaryCard.swift
//  DialedIn
//
//  Monday's one-line recap of last week at the top of the feed, dismissible for the week.
//

import SwiftUI

struct CircleWeeklySummaryCard: View {

    @Environment(\.colorScheme) private var colorScheme

    let summary: CircleWeek.Summary
    let onDismissPressed: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title3)
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text(summary.text)
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 0)
            Button(role: .close, action: onDismissPressed)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Dismiss last week's summary")
        }
        .padding()
        .background(colorScheme.backgroundPrimary, in: .rect(cornerRadius: 24))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

#Preview {
    CircleWeeklySummaryCard(
        summary: CircleWeek.Summary(weekId: "2026-W10", ownSessions: 3, ownGoal: 3, circleSessions: 11),
        onDismissPressed: { }
    )
}
