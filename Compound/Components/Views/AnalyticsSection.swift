//
//  AnalyticsSection.swift
//  Compound
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

/// The grid and list-row treatment every Analytics section shares. Two columns on a phone and up to
/// four as the screen widens, so a tile stays tile-sized on iPad and Mac. One column at the
/// accessibility sizes, where two tiles side by side truncate their titles and values.
struct AnalyticsCardGrid<Content: View>: View {

    /// The narrowest a tile gets before the grid drops a column.
    private static var tileWidth: CGFloat { 220 }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder var content: () -> Content
    @State private var width: CGFloat = 0

    private var columnCount: Int {
        dynamicTypeSize.isAccessibilitySize ? 1 : min(4, max(2, Int(width / Self.tileWidth)))
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(), count: columnCount)) {
            content()
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
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
            value: value,
            unit: unit,
            themeColor: themeColor,
            chartConfiguration: .compact
        ) {
            SparklineChart(
                data: data,
                color: themeColor
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
            value: value,
            unit: String(localized: "this week"),
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

    let message: String

    var body: some View {
        Text(message)
            .font(.label)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: AnalyticsCardLayout.minHeight)
            .padding()
            .cardSurface(.tile)
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
                    themeColor: Color.Metric.scaleWeight,
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
