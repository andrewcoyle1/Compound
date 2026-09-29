//
//  ChallengeRing.swift
//  DialedIn
//

import SwiftUI

/// A progress ring with the count inside: the Dashboard card's "my progress" and the detail header.
struct ChallengeRing: View {
    let sessions: Int
    let target: Int
    var size: CGFloat = 56

    /// Grows the ring with Dynamic Type so the count inside keeps its proportion.
    @ScaledMetric(relativeTo: .subheadline) private var scale: CGFloat = 1

    private var progress: Double {
        ChallengeStandings.ringProgress(sessions: sessions, target: target)
    }

    private var side: CGFloat { size * scale }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.tintedSurface(.accentColor), lineWidth: side / 9)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progress >= 1 ? Color.success : Color.accentColor, style: StrokeStyle(lineWidth: side / 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(sessions)/\(target)")
                .font(size >= 80 ? .metric : .metricSmall)
                .lineLimit(1)
                .padding(side / 8)
        }
        .frame(width: side, height: side)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(sessions) of \(target) sessions")
    }
}

#Preview {
    HStack {
        ChallengeRing(sessions: 3, target: 12)
        ChallengeRing(sessions: 12, target: 12, size: 88)
    }
}
