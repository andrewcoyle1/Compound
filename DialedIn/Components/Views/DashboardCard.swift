//
//  DashboardCard.swift
//  DialedIn
//
//  The frame the Dashboard's carousel cards share. Today's Workout, Workout Streak and Nutrition
//  each drew their own title and rounded surface, and each sized itself differently — one had no
//  height at all, one put 200pt on the surface, one put it on the title and surface together — so
//  the three pages of a single `TabView` did not line up with each other.
//

import SwiftUI

struct DashboardCard<Content: View>: View {

    let title: String
    /// Cards whose content brings its own surface (the Today's Workout label styles itself) opt out
    /// of the rounded background rather than nesting two.
    var drawsSurface: Bool = true
    @ViewBuilder var content: () -> Content

    /// The height every page of the Dashboard carousel starts from. A minimum: the content grows
    /// past it at large text sizes.
    static var contentHeight: CGFloat { 200 }

    /// The title above the surface, plus the stack's spacing. The carousel sizes its scroll area
    /// from `contentHeight + titleHeight` rather than the `+ 60` guess it used to carry.
    static var titleHeight: CGFloat { 30 }

    var body: some View {
        VStack(alignment: .leading) {
            // Wraps rather than shrinking: "Today's Workout" is wider than a card at accessibility
            // sizes, and half-size text defeats the point of the larger size. A heading, so the
            // VoiceOver rotor can move between the carousel's cards.
            Text(title)
                .font(.sectionTitle)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            // A minimum, not a fixed height, so the content grows with Dynamic Type instead of
            // being cropped.
            surface
                .frame(minHeight: Self.contentHeight)
        }
    }

    @ViewBuilder
    private var surface: some View {
        if drawsSurface {
            content()
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface(.card)
        } else {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("Dashboard card, light") {
    dashboardCardSample.preferredColorScheme(.light)
}

#Preview("Dashboard card, dark") {
    dashboardCardSample.preferredColorScheme(.dark)
}

#Preview("Dashboard card, accessibility size") {
    dashboardCardSample.dynamicTypeSize(.accessibility3)
}

@MainActor private var dashboardCardSample: some View {
    DashboardCard(title: "Workout Streak") {
        VStack(alignment: .leading) {
            Text("12 days")
                .font(.display)
            Spacer()
            Stat(value: "21 days", label: "Best streak", size: .small)
        }
    }
    .padding()
    .background(Color.canvas)
}
