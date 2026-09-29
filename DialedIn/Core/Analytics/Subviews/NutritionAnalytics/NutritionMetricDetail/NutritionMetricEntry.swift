//
//  NutritionMetricEntry.swift
//  DialedIn
//
//  Created by Cursor on 06/02/2026.
//

import Foundation

struct NutritionMetricEntry: MetricEntry {
    let id: String
    let date: Date
    let value: Double
    let metric: NutritionMetric
    /// When present (for macros), displayValue shows all three.
    let proteinGrams: Double?
    let carbGrams: Double?
    let fatGrams: Double?

    init(
        id: String = UUID().uuidString,
        date: Date,
        value: Double,
        metric: NutritionMetric,
        proteinGrams: Double? = nil,
        carbGrams: Double? = nil,
        fatGrams: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.value = value
        self.metric = metric
        self.proteinGrams = proteinGrams
        self.carbGrams = carbGrams
        self.fatGrams = fatGrams
    }

    var displayLabel: String {
        date.formatted(.dateTime.day().month().year())
    }

    var displayValue: String {
        if let protein = proteinGrams, let carbs = carbGrams, let fats = fatGrams {
            let fmt: (Double) -> String = { $0 >= 100 || $0 == floor($0) ? Int($0).formatted() : $0.formatted(.number.precision(.fractionLength(1))) }
            return String(localized: "\(String(describing: fmt(protein)))g P · \(String(describing: fmt(carbs)))g C · \(String(describing: fmt(fats)))g F")
        }
        if value >= 100 || value == floor(value) {
            return Int(value).formatted()
        }
        return value.formatted(.number.precision(.fractionLength(1)))
    }

    var systemImageName: String {
        metric.systemImageName
    }

    func timeSeriesData() -> [MetricTimeSeriesPoint] {
        [MetricTimeSeriesPoint(seriesName: metric.title, date: date, value: value)]
    }
}
