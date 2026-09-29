//
//  AnalyticsSection.swift
//  DialedIn
//
//  The repeatable pieces every Analytics section is built from. Each section used to inline its
//  own copy of the grid, the header and the sparkline card, which is how they drifted apart —
//  two headers baselined their "See All" differently, three used `.anyButton` where the rest used
//  `.anyButton(.press)`, and every sparkline restated the same 36pt configuration.
//

import SwiftUI

extension AnalyticsCardChartConfiguration {

    /// The size every card in the Analytics tab's grids uses. The default initialiser's larger
    /// numbers are for a card shown on its own, not two-up in a grid.
    static let compact = AnalyticsCardChartConfiguration(height: 36, verticalPadding: 2)
}

extension View {

    /// The tap treatment shared by every Analytics card, so a new card cannot pick a different one.
    func analyticsCardButton(action: @escaping () -> Void) -> some View {
        tappableBackground()
            .anyButton(.press, action: action)
    }
}

/// The two-column grid and list-row treatment every Analytics section shares.
struct AnalyticsCardGrid<Content: View>: View {

    @ViewBuilder var content: () -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(), GridItem()]) {
            content()
        }
        .padding(.horizontal)
        .removeListRowFormatting()
    }
}

// The section header that lived here is now `SectionHeaderView` in its own file: the Dashboard
// wanted the same header, and importing an `Analytics`-named component into another tab is how a
// second, slightly different copy gets written instead.

/// The line-chart card used for every trend metric on the Analytics tab.
struct SparklineAnalyticsCard: View {

    let title: String
    let subtitle: String
    let value: String
    let unit: String
    let themeColor: Color
    let data: [(date: Date, value: Double)]
    let action: () -> Void

    var body: some View {
        AnalyticsCard(
            title: title,
            subtitle: subtitle,
            subsubtitle: value,
            subsubsubtitle: unit,
            themeColor: themeColor,
            chartConfiguration: .compact
        ) {
            SparklineChart(
                data: data,
                configuration: SparklineConfiguration(
                    lineColor: themeColor,
                    lineWidth: 2,
                    fillColor: themeColor,
                    height: AnalyticsCardChartConfiguration.compact.height
                )
            )
        }
        .analyticsCardButton(action: action)
    }
}

/// The 30-day dot grid used by the Habits section.
struct ConsistencyAnalyticsCard: View {

    let title: String
    let value: String
    let themeColor: Color
    let data: [Double]
    let action: () -> Void

    var body: some View {
        AnalyticsCard(
            title: title,
            subtitle: String(localized: "Last 30 Days"),
            subsubtitle: value,
            subsubsubtitle: "this week",
            themeColor: themeColor,
            chartConfiguration: .compact
        ) {
            // The static grid, not `ContributionChart`: a card is one tap target that opens the
            // full chart, so it must not scroll or take a press of its own.
            ContributionGridView(
                grid: ContributionGrid(values: data, layout: .packed(rows: 3, columns: 10)),
                color: themeColor,
                style: .card()
            )
        }
        .analyticsCardButton(action: action)
    }
}

/// Stands in for a grid that has nothing to show yet, so a visible section header is never followed
/// by blank space.
struct AnalyticsEmptyCard: View {

    @Environment(\.colorScheme) private var colorScheme

    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .padding()
            .background(colorScheme.backgroundPrimary)
            .cornerRadius(16)
    }
}

#Preview {
    List {
        Section {
            AnalyticsCardGrid {
                SparklineAnalyticsCard(
                    title: "Scale Weight",
                    subtitle: "Last 7 Entries",
                    value: "82.4",
                    unit: "kg",
                    themeColor: .green,
                    data: (0..<7).map { (date: Date().addingTimeInterval(Double($0) * 86_400), value: Double(80 + $0)) },
                    action: { }
                )
                AnalyticsEmptyCard(message: "No exercises logged yet.")
            }
        } header: {
            SectionHeaderView(title: "Body Metrics", onActionPressed: { })
        }
        .listSectionMargins(.horizontal, 0)
    }
}
