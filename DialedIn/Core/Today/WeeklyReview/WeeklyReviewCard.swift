//
//  WeeklyReviewCard.swift
//  DialedIn
//
//  Today's way in to the Weekly Review, shown on the first day of the week.
//

import SwiftUI

struct WeeklyReviewCard: View {

    let onPressed: () -> Void

    var body: some View {
        Button(action: onPressed) {
            HStack(spacing: Spacing.m) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .iconSize(.medium)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Your weekly review is ready")
                    .font(.rowTitle)
                    .fontWeight(.medium)
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.label)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding()
            .cardSurface()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WeeklyReviewCard { }
}
