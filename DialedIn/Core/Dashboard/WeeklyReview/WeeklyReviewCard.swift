//
//  WeeklyReviewCard.swift
//  DialedIn
//
//  The Dashboard's way in to the Weekly Review, shown on the first day of the week.
//

import SwiftUI

struct WeeklyReviewCard: View {

    @Environment(\.colorScheme) private var colorScheme

    let onPressed: () -> Void

    var body: some View {
        Button(action: onPressed) {
            HStack(spacing: 12) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                Text("Your weekly review is ready")
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding()
            .background(colorScheme.backgroundPrimary, in: .rect(cornerRadius: 24))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

#Preview {
    WeeklyReviewCard { }
}
