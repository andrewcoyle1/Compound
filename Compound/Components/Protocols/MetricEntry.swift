import Foundation

struct MetricTimeSeriesPoint {
    let seriesName: String
    let date: Date
    let value: Double
}

protocol MetricEntry: Identifiable {
    var id: String { get }
    var date: Date { get }
    var displayLabel: String { get }
    var displayValue: String { get }
    var systemImageName: String { get }
    func timeSeriesData() -> [MetricTimeSeriesPoint]
}
