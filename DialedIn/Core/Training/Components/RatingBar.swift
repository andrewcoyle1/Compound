//
//  RatingBar.swift
//  DialedIn
//

import SwiftUI

/// A 0–5 rating as five capsules, filled in the accent up to `value`. Used for an exercise's range
/// of motion and stability while it is being created and when it is reviewed.
struct RatingBar: View {
    let value: Int
    var maximum: Int = 5

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(1...maximum, id: \.self) { step in
                Capsule()
                    .fill(step <= value ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.tintedSurface(.secondary)))
                    .frame(height: Spacing.s)
            }
        }
        .frame(maxWidth: 200)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(String(localized: "\(value) of \(maximum)"))
    }
}

#Preview {
    List {
        RatingBar(value: 0)
        RatingBar(value: 3)
        RatingBar(value: 5)
    }
}
