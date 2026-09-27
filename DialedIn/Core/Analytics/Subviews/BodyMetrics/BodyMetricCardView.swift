import SwiftUI

struct BodyMetricCardView: View {
    let card: BodyMetricCardModel
    let themeColor: Color
    let onPress: () -> Void

    var body: some View {
        AnalyticsCard(
            title: card.title,
            subtitle: card.subtitle,
            value: card.latestValueText,
            unit: card.unitText,
            themeColor: themeColor,
            chartConfiguration: .compact
        ) {
            SparklineChart(
                data: card.sparklineData,
                configuration: SparklineConfiguration(
                    lineColor: themeColor,
                    lineWidth: 2,
                    fillColor: themeColor,
                    height: AnalyticsCardChartConfiguration.compact.height
                )
            )
        }
        .analyticsCardButton(action: onPress)
    }
}

/// The same card for a derived ratio. A ratio has no unit, so `unit` is omitted rather
/// than filled with something.
struct BodyRatioCardView: View {
    let card: BodyRatioCardModel
    let themeColor: Color
    let onPress: () -> Void

    var body: some View {
        AnalyticsCard(
            title: card.title,
            subtitle: card.subtitle,
            value: card.latestValueText,
            unit: nil,
            themeColor: themeColor,
            chartConfiguration: .compact
        ) {
            SparklineChart(
                data: card.sparklineData,
                configuration: SparklineConfiguration(
                    lineColor: themeColor,
                    lineWidth: 2,
                    fillColor: themeColor,
                    height: AnalyticsCardChartConfiguration.compact.height
                )
            )
        }
        .analyticsCardButton(action: onPress)
    }
}
