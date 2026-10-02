//
//  FeatureUnavailableView.swift
//  Compound
//

import SwiftUI

/// A screen for a feature the app advertises but cannot do yet.
///
/// Exists so that a Profile row leading to unbuilt work says so, instead of opening a blank screen
/// or doing nothing at all. Silence reads as a bug; this reads as a plan. Every use names what is
/// actually missing rather than saying "coming soon" — the reason is the useful part, both for
/// whoever taps it and for whoever picks the work up.
struct FeatureUnavailableView: View {

    let title: String
    let systemImage: String

    /// One or two sentences on what the feature will do, in plain language.
    let summary: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(summary)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        FeatureUnavailableView(
            title: "Siri",
            systemImage: "siri",
            summary: "Asking Siri to log a meal or start a workout is not available yet. It needs Shortcuts support in the app, which is still being built."
        )
    }
}
