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

    private var progress: Double {
        ChallengeStandings.ringProgress(sessions: sessions, target: target)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.2), lineWidth: size / 9)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progress >= 1 ? Color.green : Color.accentColor, style: StrokeStyle(lineWidth: size / 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(sessions)/\(target)")
                .font(.system(size: size / 4.5, weight: .semibold).monospacedDigit())
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(size / 8)
        }
        .frame(width: size, height: size)
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
