//
//  EnergyBalanceChart.swift
//  DialedIn
//
//  Created by Andrew Coyle on 07/02/2026.
//

import SwiftUI

/// The thumbnail on the Energy Balance cards: the last week's intake as bars with expenditure drawn
/// over them. QuickCharts' `ChartThumbnail`, so it takes no touches; the screen behind the card
/// draws the same shape with `ComboChart`.
struct EnergyBalanceChart: View {

    let expenditure: TimeSeries
    let energyIntake: TimeSeries

    /// How many days the thumbnail shows.
    private static let visibleDays = 7

    private let expenditurePoints: [TimeSeriesDatapoint]
    private let intakePoints: [TimeSeriesDatapoint]

    init(expenditure: TimeSeries, energyIntake: TimeSeries) {
        self.expenditure = expenditure
        self.energyIntake = energyIntake
        // `sortedByDate` is cached on `TimeSeries`; the window is its tail.
        expenditurePoints = Array(expenditure.sortedByDate.suffix(Self.visibleDays))
        intakePoints = Array(energyIntake.sortedByDate.suffix(Self.visibleDays))
    }

    var body: some View {
        ChartThumbnail(
            data: [
                TimeSeries(name: Self.intakeName, data: intakePoints),
                TimeSeries(name: Self.expenditureName, data: expenditurePoints)
            ],
            style: .combo(lineSeries: [Self.expenditureName]),
            colors: [Self.intakeColor, Self.expenditureColor]
        )
        .accessibilityElement()
        .accessibilityLabel(Text("Energy balance, last \(Self.visibleDays) days"))
        .accessibilityValue(accessibilitySummary)
    }

    /// "Average intake 2,100 kcal, expenditure 2,450 kcal".
    private var accessibilitySummary: String {
        func average(_ points: [TimeSeriesDatapoint]) -> String {
            guard !points.isEmpty else { return Format.placeholder }
            return Format.kcal(points.map(\.value).reduce(0, +) / Double(points.count))
        }
        return String(localized: "Average intake \(average(intakePoints)), expenditure \(average(expenditurePoints))")
    }

    private static let intakeName = "Intake"
    private static let expenditureName = "Expenditure"

    /// The colours the full chart uses, so the card and the screen it opens match.
    static let intakeColor: Color = .calories
    static let expenditureColor: Color = Color.Metric.expenditure
}

#Preview {
    EnergyBalanceChart(expenditure: TimeSeries.last14Days, energyIntake: TimeSeries.last14Days)
        .padding()
}
