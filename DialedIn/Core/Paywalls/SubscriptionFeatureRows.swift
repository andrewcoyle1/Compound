//
//  SubscriptionFeatureRows.swift
//  DialedIn
//
//  What the subscription includes, listed once for "Why Subscribe?" and both paywalls, so the
//  paywall names real features rather than "exclusive features for premium members".
//

import SwiftUI

struct SubscriptionFeatureRows: View {
    var body: some View {
        OnboardingFeatureRow(title: "Personalized plans", detail: "Training and nutrition tailored to your goals and schedule.", systemImage: Symbol.mesocycle)
        OnboardingFeatureRow(title: "Smart coaching", detail: "Daily guidance powered by your data and AI insights.", systemImage: Symbol.knowledgeBase)
        OnboardingFeatureRow(title: "Progress tracking", detail: "See trends, weekly summaries, and PRs at a glance.", systemImage: Symbol.analytics)
        OnboardingFeatureRow(title: "Apple Health sync", detail: "Automatically log workouts and recovery from Apple Health.", systemImage: "heart.circle")
        OnboardingFeatureRow(title: "Accountability", detail: "Reminders and nudges to help you stay consistent.", systemImage: Symbol.notifications)
    }
}
