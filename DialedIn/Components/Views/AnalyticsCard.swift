//
//  AnalyticsCard.swift
//  DialedIn
//
//  Created by Andrew Coyle on 04/02/2026.
//

import SwiftUI

struct AnalyticsCardChartConfiguration {
    var height: CGFloat = 44
    var verticalPadding: CGFloat = 4
}

/// The height an Analytics tile starts from. It is a minimum, so the tile grows with Dynamic Type.
enum AnalyticsCardLayout {
    static let minHeight: CGFloat = 120
}

/// A grid tile: title and subtitle, a small chart, then the latest value and its unit.
struct AnalyticsCard<MetricChart: View>: View {

    var title: String?
    var subtitle: String?
    /// The headline number, e.g. "82.4".
    var value: String?
    /// Shown after `value`, e.g. "kg" or "sets".
    var unit: String?
    /// Leads the title, tinted `themeColor`.
    var systemImage: String?
    /// The metric's colour. Tints the title symbol and the chart.
    var themeColor: Color?
    /// Pass `false` for a card that does not open anything.
    var showsChevron: Bool
    var chartConfiguration: AnalyticsCardChartConfiguration
    var chart: () -> MetricChart

    init(
        title: String? = nil,
        subtitle: String? = nil,
        value: String? = nil,
        unit: String? = nil,
        systemImage: String? = nil,
        themeColor: Color? = nil,
        showsChevron: Bool = true,
        chartConfiguration: AnalyticsCardChartConfiguration = AnalyticsCardChartConfiguration(),
        chart: @escaping () -> MetricChart
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.unit = unit
        self.systemImage = systemImage
        self.themeColor = themeColor
        self.showsChevron = showsChevron
        self.chartConfiguration = chartConfiguration
        self.chart = chart
    }

    @available(*, deprecated, renamed: "init(title:subtitle:value:unit:systemImage:themeColor:showsChevron:chartConfiguration:chart:)")
    init(
        title: String? = nil,
        subtitle: String? = nil,
        subsubtitle: String?,
        subsubsubtitle: String?,
        themeColor: Color? = nil,
        chartConfiguration: AnalyticsCardChartConfiguration = AnalyticsCardChartConfiguration(),
        chart: @escaping () -> MetricChart
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            value: subsubtitle,
            unit: subsubsubtitle,
            themeColor: themeColor,
            chartConfiguration: chartConfiguration,
            chart: chart
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                if let title {
                    HStack(spacing: Spacing.xs) {
                        if let systemImage {
                            Image(systemName: systemImage)
                                .foregroundStyle(themeColor ?? .secondary)
                        }
                        Text(title)
                            .lineLimit(1)
                    }
                    .font(.sectionTitle)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.label)
                        .foregroundStyle(.secondary)
                }
            }

            chart()
                .tint(themeColor)
                .frame(maxWidth: .infinity)
                .frame(height: chartConfiguration.height)
                .padding(.vertical, chartConfiguration.verticalPadding)

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                if let value {
                    Text(value)
                        .font(.metricSmall)
                        .lineLimit(1)
                }
                if let unit {
                    Text(unit)
                        .font(.label)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.label)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: AnalyticsCardLayout.minHeight, alignment: .topLeading)
        .padding()
        .cardSurface(.tile)
    }
}

// MARK: - Preview

private struct AnalyticsCardPreview: View {
    var body: some View {
        List {
            Section {
                LazyVGrid(columns: [GridItem(), GridItem()]) {
                    AnalyticsCard(
                        title: "Protein",
                        subtitle: "Today",
                        value: "112.4",
                        unit: "g",
                        systemImage: Symbol.protein,
                        themeColor: .protein,
                        chartConfiguration: .compact
                    ) {
                        MacroProgressChart(current: 112, target: 150, maxValue: 180, color: .protein)
                    }
                    AnalyticsCard(
                        title: "Workouts",
                        subtitle: "Last 30 Days",
                        value: "12",
                        unit: "this week",
                        themeColor: Color.Metric.workouts,
                        chartConfiguration: .compact
                    ) {
                        ContributionGridView(
                            grid: ContributionGrid(values: [0, 0.1, 0.3, 0.5, 0.7, 0.9], layout: .packed(rows: 3, columns: 10)),
                            color: Color.Metric.workouts,
                            style: .card()
                        )
                    }
                    AnalyticsCard(
                        title: "Iron",
                        subtitle: "Not Tracked",
                        value: "--",
                        unit: "mg",
                        themeColor: .minerals,
                        showsChevron: false,
                        chartConfiguration: .compact
                    ) {
                        MacroProgressChart(current: 0, target: nil, maxValue: 50, color: .minerals)
                    }
                    AnalyticsEmptyCard(message: "No exercises logged yet.")
                }
                .removeListRowFormatting()
                .padding(.horizontal)
            }
            .listSectionMargins(.horizontal, 0)
        }
    }
}

#Preview("Analytics card, light") {
    AnalyticsCardPreview().preferredColorScheme(.light)
}

#Preview("Analytics card, dark") {
    AnalyticsCardPreview().preferredColorScheme(.dark)
}

#Preview("Analytics card, accessibility size") {
    AnalyticsCardPreview().dynamicTypeSize(.accessibility3)
}
