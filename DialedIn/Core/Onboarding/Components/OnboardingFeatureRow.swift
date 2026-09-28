//
//  OnboardingFeatureRow.swift
//  DialedIn
//

import SwiftUI

/// A benefit on an onboarding pitch screen: an accent glyph beside a title and a sentence.
/// Intro, Subscription, Notifications and Health Data each drew their own copy.
struct OnboardingFeatureRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
            Image(systemName: systemImage)
                .iconSize(.medium)
                .foregroundStyle(.tint)
                .frame(minWidth: IconSize.medium.points)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.sectionTitle)
                Text(detail)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        OnboardingFeatureRow(title: "Track Your Workouts", detail: "Log your strength and cardio sessions.", systemImage: Symbol.workout)
        OnboardingFeatureRow(title: "Monitor Your Nutrition", detail: "Easily log meals and scan foods.", systemImage: Symbol.nutrition)
    }
}
